## インストール

- Ruby 2.0 （1.9でも大丈夫かな？）
- [Nokogiri](http://www.nokogiri.org/tutorials/installing_nokogiri.html)
- git clone https://github.com/mobitan/mercalert.git
- cd mercalert
- cp sample-config.yml config.yml

## 使い方

config.yml に設定を書いたあと mercalert.rb を実行。

	./mercalert.rb [options]
	options:
	  --conf=FILE           read config from FILE (default='config.yml')
	  --cp=FILE             duplicate the resulting html to FILE
	  --interval=SECONDS    minimum interval time from previous run

終わったら log/YYYYMMDD-HHMMSS.html を好きなブラウザで開く。

## 設定

### ターゲット:

ハッシュのリスト。中身は以下のとおり。

- **検索:** 文字列のリスト。キーワードを列挙する（複数可）。
- **カテゴリ:** 文字列のリスト。カテゴリを列挙する（複数可）。フォーマットは "親カテゴリ番号/子カテゴリ番号/孫カテゴリ番号1/孫カテゴリ番号2/..."。たとえばURLが category_root=7&category_child=96&category_grand_child[841]=1&category_grand_child[1156]=1 ならカテゴリは 7/96/841/1156 とする。
- **サイズ:** 文字列。フォーマットは "サイズグループ番号/サイズ番号1/サイズ番号2/..."。たとえばURLが size_group=17&size_id[118]=1&size_id[124]=1 ならサイズは 17/118/124 とする。
- **価格:** 整数のリスト。[Min, Max].
- **状態:** 整数のリスト。1: 新品、未使用, 2: 未使用に近い, 3: 目立った傷や汚れなし, 4: やや傷や汚れあり, 5: 傷や汚れあり, 6: 全体的に状態が悪い.
- **除外:** 正規表現。タイトルまたは説明文にマッチしたら除外される。
- **除外カテゴリ:** 正規表現。カテゴリの表示文字列にマッチしたら除外される。
- **除外サイズ:** 正規表現。サイズの表示文字列にマッチしたら除外される。
- **ページ数:** 整数。省略時は1ページ。

### ブラックリスト:

文字列のリスト。除外したいユーザーIDを列挙する。

### 通知メール:

ハッシュ。中身は以下のとおり。

- **to:** 文字列。送信先メールアドレス。
- **type:** 整数。1: 生HTML, 2: uuencodeしたHTML.

メール通知機能はmailコマンドを利用。Macでしか動作確認していない。
