## �C���X�g�[��

- Ruby 2.0 �i1.9�ł����v���ȁH�j
- [Nokogiri](http://www.nokogiri.org/tutorials/installing_nokogiri.html)
- git clone https://github.com/mobitan/mercalert.git
- cd mercalert
- cp sample-config.yml config.yml

## �g����

config.yml �ɐݒ������������ mercalert.rb �����s�B

	./mercalert.rb [options]
	options:
	  --conf=FILE           read config from FILE (default='config.yml')
	  --cp=FILE             duplicate the resulting html to FILE
	  --interval=SECONDS    minimum interval time from previous run

�I������� log/YYYYMMDD-HHMMSS.html ���D���ȃu���E�U�ŊJ���B

## �ݒ�

### �^�[�Q�b�g:

�n�b�V���̃��X�g�B���g�͈ȉ��̂Ƃ���B

- **����:** ������̃��X�g�B�L�[���[�h��񋓂���i�����j�B
- **�J�e�S��:** ������̃��X�g�B�J�e�S����񋓂���i�����j�B�t�H�[�}�b�g�� "�e�J�e�S���ԍ�/�q�J�e�S���ԍ�/���J�e�S���ԍ�1/���J�e�S���ԍ�2/..."�B���Ƃ���URL�� category_root=7&category_child=96&category_grand_child[841]=1&category_grand_child[1156]=1 �Ȃ�J�e�S���� 7/96/841/1156 �Ƃ���B
- **�T�C�Y:** ������B�t�H�[�}�b�g�� "�T�C�Y�O���[�v�ԍ�/�T�C�Y�ԍ�1/�T�C�Y�ԍ�2/..."�B���Ƃ���URL�� size_group=17&size_id[118]=1&size_id[124]=1 �Ȃ�T�C�Y�� 17/118/124 �Ƃ���B
- **���i:** �����̃��X�g�B[Min, Max].
- **���:** �����̃��X�g�B1: �V�i�A���g�p, 2: ���g�p�ɋ߂�, 3: �ڗ��������≘��Ȃ�, 4: ��⏝�≘�ꂠ��, 5: ���≘�ꂠ��, 6: �S�̓I�ɏ�Ԃ�����.
- **���O:** ���K�\���B�^�C�g���܂��͐������Ƀ}�b�`�����珜�O�����B
- **���O�J�e�S��:** ���K�\���B�J�e�S���̕\��������Ƀ}�b�`�����珜�O�����B
- **���O�T�C�Y:** ���K�\���B�T�C�Y�̕\��������Ƀ}�b�`�����珜�O�����B
- **�y�[�W��:** �����B�ȗ�����1�y�[�W�B

### �u���b�N���X�g:

������̃��X�g�B���O���������[�U�[ID��񋓂���B

### �ʒm���[��:

�n�b�V���B���g�͈ȉ��̂Ƃ���B

- **to:** ������B���M�惁�[���A�h���X�B
- **type:** �����B1: ��HTML, 2: uuencode����HTML.

���[���ʒm�@�\��mail�R�}���h�𗘗p�BMac�ł�������m�F���Ă��Ȃ��B
