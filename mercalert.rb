#!/usr/bin/ruby -Ku
#
#   	Mercalert
#   	2018/09/04  by mobitan
#

$help_message = <<-EOM
Usage: #{$0} [Options]

Options:
  --conf=FILE           read config from FILE (default='config.yml')
  --cp=FILE             duplicate the resulting html to FILE
  --interval=SECONDS    minimum interval time from the previous run
  --debug=[0][1][2][3][4]
                        run only the specified part of the program
                        0: logging
                        1: load_logs
                        2: fetch_list
                        3: fetch_item
                        4: notify_updates
EOM

require "optparse"
require "pathname"
require "open-uri"
require "cgi/util"
require "nokogiri"
require "yaml"
require "date"
require "set"
require "pp"

def main
	st = Time.now
	$opts = ARGV.getopts("", "conf:#{File.dirname(__FILE__)}/config.yml", "cp:", "interval:", "debug:")
	$timestamp = DateTime.now.strftime("%Y%m%d-%H%M%S")
	$logdir = Pathname.new(File.dirname(__FILE__)) + "log"
	$htfile = $logdir + "#{$timestamp}.html"
	$okfile = $logdir + "!#{$timestamp}.tsv"
	$ngfile = $logdir + "excluded.tsv"
	$okcount = 0
	$logdir.mkdir unless $logdir.directory?
	$checked = load_checked_logs($logdir + "20??????-??????.tsv")
	$excluded = load_excluded_logs($ngfile)
	$stdout.sync = true
	
	lastokfile = latest_checked_log($logdir + "20??????-??????.tsv")
	if lastokfile
		lapse = (Time.now - lastokfile.mtime).to_i
		if lapse <= $opts["interval"].to_i
			$stderr.puts "Ran #{lapse} seconds ago"
			exit(0)
		end
	end
	puts "\n========  #{$timestamp}  ========"
	open($opts["conf"]) do |f|
		$conf = YAML.load(f)
	end
	puts $conf
	$excl = Hash.new
	$excl["seller"] = Regexp.new($conf["ブラックリスト"].join("|"))
	$conf["ターゲット"].each do |target|
		target["検索"] ||= [""]
		target["カテゴリ"] ||= [""]
		$excl["keyword"]  = target["除外"]         && Regexp.new(target["除外"], Regexp::IGNORECASE)
		$excl["category"] = target["除外カテゴリ"] && Regexp.new(target["除外カテゴリ"], Regexp::IGNORECASE)
		$excl["size"]     = target["除外サイズ"]   && Regexp.new(target["除外サイズ"], Regexp::IGNORECASE)
		$excl["status"]   = target["除外状態"]     && Regexp.new(target["除外状態"], Regexp::IGNORECASE)
		target["検索"].each do |keyword|
			target["カテゴリ"].each do |category|
				fetch_list(target, keyword.to_s, category.to_s)
			end
		end
	end
	if $htfile.exist?
		html_enclose($htfile)
	end
	if $okfile.exist?
		notify_updates($conf["通知メール"])
		overwrite(Pathname.new($opts["cp"]), $htfile.read) if $opts["cp"]
		# 処理が完了した場合に限り、今回のログファイルを次回の読み込み対象とする
		$okfile.rename($logdir + "#{$timestamp}.tsv") 
	end
	puts format("Done in %i sec.", Time.now - st)
end

# 最新のログファイル
def latest_checked_log(pattern)
	Pathname.glob(pattern).max_by{|path| path.mtime }
end

# 確認済みログを読み込む
def load_checked_logs(pattern)
	data = Set.new
	if $opts["debug"]
		return data unless $opts["debug"].include?("1")
	end
	Pathname.glob(pattern).each do |path|
		IO.readlines(path).each do |line|
			data.add(line.chomp)
		end
	end
	data
end

# 除外済みログを読み込む
def load_excluded_logs(pattern)
	data = Hash.new
	if $opts["debug"]
		return data unless $opts["debug"].include?("1")
	end
	Pathname.glob(pattern).each do |path|
		IO.readlines(path).each do |line|
			key, value = line.split("\t", 2)
			data[key] = value.chomp
		end
	end
	data
end

# 一覧ページの処理
def fetch_list(target, keyword, category)
	if $opts["debug"]
		return unless $opts["debug"].include?("2")
	end
	if category.empty?
		puts "\nProcessing \"#{keyword}\""
	else
		puts "\nProcessing \"#{keyword}\" in category #{category}"
	end
	params = Hash.new
	params["status_on_sale"] = 1
	params["sort_order"] = "created_desc"
	if !keyword.empty?
		params["keyword"] = CGI.escape(keyword)
	end
	if !category.empty?
		cats = category.split(/\D/)
		params["category_root"]  = cats.shift
		params["category_child"] = cats.shift
		until cats.empty?
			params["category_grand_child[#{cats.shift}]"] = 1
		end
	end
	if target["サイズ"]
		sizes = target["サイズ"].split(/\D/)
		params["size_group"] = sizes.shift
		until sizes.empty?
			params["size_id[#{sizes.shift}]"] = 1
		end
	end
	if target["価格"]
		params["price_min"] = target["価格"][0]
		params["price_max"] = target["価格"][1]
	end
	if target["状態"]
		target["状態"].each do |n|
			params["item_condition_id[#{n}]"] = 1
		end
	end
	target["ページ数"] ||= 1
	pages = 1..(target["ページ数"].to_i)
	pages.each do |page|
		list_url = "https://www.mercari.com/jp/search/?page=#{page}&" + params.collect{|k, v| "#{k}=#{v}" }.join("&")
		retry_count = 0
		begin
			open(list_url) do |f|
				html = f.read
				charset = f.charset
				doc = Nokogiri::HTML.parse(html, nil, charset)
				if texts_in(doc, "h2.search-result-head").include?("検索結果 0件")
					puts "Not found"
					return
				end
				doc.css("section.items-box").each do |node|
					url   = node.css("a")[0].attr("href")
					title = texts_in(node, "h3")
					price = texts_in(node, "div.items-box-price").gsub(/\D/, "").to_i
					sold  = node.css("div.item-sold-out-badge")[0]
					entry = format("%s\t%5i\t%s", url, price, title)
					puts entry
					if $checked.include?(entry)
						puts "    [ SKIP ]"
					elsif sold
						puts "    [ SOLD ]"
					elsif $excl["keyword"] =~ title
						puts "    [  NG  ] タイトル \"#{$&}\""
					else
						fetch_item(target, url, entry)
					end
					$checked.add(entry)
				end
				if doc.css("li.pager-next").empty?
					puts "Found #{page} pages"
					return
				end
			end
		rescue OpenURI::HTTPError
			puts $!.message
			puts list_url
			retry_count += 1
			if retry_count < 3
				puts "Retry #{retry_count}"
				sleep(5 * retry_count)
				retry
			end
		rescue
			puts $!.message
			puts list_url
		end
		sleep(1)
	end
end

# 個別ページの処理
def fetch_item(target, item_url, entry)
	if $opts["debug"]
		return unless $opts["debug"].include?("3")
	end
	if $excluded.include?(item_url)
		key, value = $excluded[item_url].split("\t")
		if $excl[key] =~ value
			puts "    [  NG  ] #{key} \"#{$&}\""
			return
		end
		$excluded.delete(item_url)
	end
	open(item_url) do |f|
		html = f.read
		charset = f.charset
		doc = Nokogiri::HTML.parse(html, nil, charset)
		if !doc.css("h2.deleted-item-name").empty?
			puts "    [DELETE]"
			return
		end
		table = Hash.new # {thテキスト => tdテキスト}
		doc.css("table.item-detail-table tr").each do |node|
			table[texts_in(node, "th")] = texts_in(node, "td")
			if texts_in(node, "th") == "出品者"
				table["出品者"] = texts_in(node, "a")
				table["出品者URL"] = attrs_in(node, "a", "href")
			end
		end
		if $excl["seller"] =~ table["出品者URL"]
			append($ngfile, format("%s\t%s\t%s", item_url, "seller", $&))
			puts "    [  NG  ] 出品者 \"#{$&}\""
		elsif $excl["category"] =~ table["カテゴリー"]
			append($ngfile, format("%s\t%s\t%s", item_url, "category", $&))
			puts "    [  NG  ] カテゴリ \"#{$&}\""
		elsif $excl["size"] =~ table["商品のサイズ"]
			append($ngfile, format("%s\t%s\t%s", item_url, "size", $&))
			puts "    [  NG  ] サイズ \"#{$&}\""
		elsif $excl["status"] =~ table["商品の状態"]
			append($ngfile, format("%s\t%s\t%s", item_url, "status", $&))
			puts "    [  NG  ] 状態 \"#{$&}\""
		elsif $excl["keyword"] =~ texts_in(doc, "div.item-description")
			append($ngfile, format("%s\t%s\t%s", item_url, "keyword", $&))
			puts "    [  NG  ] 説明 \"#{$&}\""
		else
			append($okfile, entry)
			append($htfile, html_entry(item_url, table, doc))
			$okcount += 1
			puts "    [  OK  ]"
		end
	end
	sleep(1)
end

# HTML エントリ生成
def html_entry(item_url, table, doc)
	item_name = texts_in(doc, "h1.item-name")
	item_price = doc.css("span.item-price")[0].text.strip
	img_urls = attrs_in(doc, "div.item-photo img", "data-src").split("\n")
	html = ""
	html << "<div class=\"entry\">\n"
	html << "<h3><span class=\"price\">#{item_price}</span> <a href=\"#{item_url}\" target=\"_blank\">#{item_name}</a> <span class=\"seller\"><a href=\"#{table['出品者URL']}\" target=\"_blank\">#{table['出品者']}</a></span></h3>\n"
	html << "<table><tbody><tr>\n"
	img_urls.each do |img_url|
		html << "<td><a href=\"#{img_url}\"><img src=\"#{img_url}\" width=\"300\"></a></td>\n"
	end
	html << "</tr></tbody></table>\n"
	html << "</div>\n"
	html
end

# ファイルに HTML のヘッダとフッタを付加
def html_enclose(path)
	content = path.read
	content = <<-EOS
<!DOCTYPE html>
<html lang="ja-JP">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mercalert</title>
<style>
h1, h2, h3 { margin: 0; }
.entry { margin: 12px; }
.price { margin-right: 12px; }
.seller { margin-left: 12px; font-size: 80%; }
td { margin: 6px; }
a { color: rgb(0,153,232); text-decoration: none; }
a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h2>Mercalert found #{$okcount} items at #{$timestamp}</h2>
#{content}
</body>
</html>
	EOS
	path.open("w") do |f|
		f.puts(content)
	end
end

# メール通知
#   mailconf["to"]: 宛先メールアドレス
#   mailconf["type"]: 0=text 1=本文HTML（動作未確認） 2=添付HTML
def notify_updates(mailconf)
	return unless mailconf
	if $opts["debug"]
		return unless $opts["debug"].include?("4")
	end
	# Macでメール送信
	mailto = mailconf["to"]
	content = $okfile.read
	case mailconf["type"].to_i
	when 1 then content = $htfile.read
	when 2 then content = `uuencode #{$htfile} #{$htfile}`
	end
	puts "Notifying #{mailto} of #{$okcount} items"
	command = "mail -s '[Mercalert] #{$okcount} new items' #{mailto}"
	IO.popen(command, "r+", $stderr => [:child, $stdout]) do |f|
		f.puts(content)
		f.close_write
		print f.read
	end
end

# ファイルに追記
def append(path, content)
	if $opts["debug"]
		return unless $opts["debug"].include?("0")
	end
	path.open("a") do |f|
		f.puts(content)
	end
end

# ファイルに上書き
def overwrite(path, content)
	if $opts["debug"]
		return unless $opts["debug"].include?("0")
	end
	path.open("w") do |f|
		f.puts(content)
	end
end

# Nokogiriノード内のテキストを取得
def texts_in(node, sel, sep="\n")
	node.css(sel).collect{|item| item.text.strip }.join(sep)
end

# Nokogiriノード内のHTML取得
def htmls_in(node, sel, sep="\n")
	node.css(sel).collect{|item| item.content.strip }.join(sep)
end

# Nokogiriノード内の属性値を取得
def attrs_in(node, sel, att, sep="\n")
	node.css(sel).collect{|item| item.attr(att).strip }.join(sep)
end

# 二重起動禁止
def exclusively
	lockfile = Pathname(__FILE__).dirname + "lockfile"
	lockfile.open("a") do |f|
		if not f.flock(File::LOCK_EX | File::LOCK_NB)
			exit(1)
		end
		f.puts($$)
		yield
	end
	lockfile.delete
end

if $0 == __FILE__
	exclusively do
		main
	end
end
