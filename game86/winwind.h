// �O���t�B�b�N�p�E�B���h�E�̃f�[�^���܂Ƃ߂��\����
typedef struct{
	HINSTANCE			hi;			// �C���X�^���X�n���h��
	int				x_size;		// �O���t�B�b�N��ʂ̑傫��
	int				y_size;
	HDC				mdc;		// �������f�o�C�X�R���e�L�X�g
	HWND				hwnd;		// �����̃E�B���h�E�n���h��
} IMG00;
// �ʃX���b�h���N�����ʃX���b�h�ŃE�B���h�E�𐶐�����
void gr_init();
