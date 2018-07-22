#include "stdafx.h"
#include <windows.h>
#include <stdio.h>
#include "winwind.h"
IMG00 img;
DWORD th_Proc();
LRESULT CALLBACK grProc(HWND, UINT, WPARAM, LPARAM);
static LPDWORD lpPixel;

//	�O���t�B�b�N�E�B���h�E�̐����C���b�Z�[�W���[�v�p�X���b�h�̋N��
void gr_init()
{
	img.hi = (HINSTANCE)GetWindowLong(HWND_DESKTOP, GWL_HINSTANCE);
	WNDCLASSEX	wc;					//�@�V��������E�C���h�N���X
	memset(&wc, 0, sizeof(WNDCLASSEX));
	wc.cbSize = sizeof(WNDCLASSEX);
	wc.lpfnWndProc = grProc;				// ���̃N���X�̎��E�C���h�v���V�[�W��
	wc.hInstance = img.hi;
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
	wc.lpszClassName = TEXT("DOS_Win");				// ���̃N���X�̖��O
	if (!RegisterClassEx(&wc)) return;				// �E�B���h�N���X�̓o�^
	DWORD tid;
	img.hwnd = 0;
	CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)th_Proc,
		NULL, 0, &tid);					// ���b�Z�[�W���[�v�̃X���b�h���N��	
	while (!img.hwnd);					// �E�B���h�E���\�������̂�҂�
}

//�@���b�Z�[�W���[�v�̂��߂̃X���b�h
DWORD th_Proc()
{
	int sm0 = GetSystemMetrics(SM_CYCAPTION);
	int sm1 = GetSystemMetrics(SM_CXFIXEDFRAME);		// WS_OVRELAPP�̏ꍇ�A�g�̑�����
	int sm2 = GetSystemMetrics(SM_CYFIXEDFRAME);		// SM_C?FIXEDFRAME�ɂȂ�
	img.hwnd = CreateWindow(TEXT("DOS_Win"),			// �N���X�̖��O
		TEXT("DOS_Win"),
		WS_OVERLAPPED | WS_VISIBLE,	// �E�B���h�E�̑���
		CW_USEDEFAULT, CW_USEDEFAULT,	// �ʒu�͎w�肵�Ȃ�
		img.x_size + sm1 * 2, 		// �`��T�C�Y����E�B���h�E�̑傫�����v�Z
		img.y_size + sm0 + sm2 * 2,
		HWND_DESKTOP,			// �e�̓f�B�X�N�g�b�v
		NULL, img.hi, NULL);	// pimg���E�B���h�E�v���V�[�W���ɓn�� 
	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)){
		DispatchMessage(&msg);
	}
	return 0;
}

//�@�E�B���h�E�v���V�[�W���C�`��I�u�W�F�N�g�̏����ƍĕ`����s��
LRESULT CALLBACK grProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	static HBITMAP hbit;

	switch (msg){
	case WM_CREATE:{
		HDC hdc = GetDC(hwnd);
		// �E�B���h�E�Ɠ������z��ʂ����
		img.mdc = CreateCompatibleDC(hdc);
		hbit = CreateCompatibleBitmap(hdc, img.x_size, img.y_size);
		SelectObject(img.mdc, hbit);
		PatBlt(img.mdc, 0, 0, img.x_size, img.y_size, BLACKNESS);	// ���z��ʂ̃N���A
		ReleaseDC(hwnd, hdc);
		break;
	}
	case WM_PAINT:{
		PAINTSTRUCT ps;
		BeginPaint(hwnd, &ps);
		//�@���z��ʂ���̃R�s�[	
		BitBlt(ps.hdc, 0, 0, img.x_size, img.y_size, img.mdc, 0, 0, SRCCOPY);
		EndPaint(hwnd, &ps);
		break;
	}
	case WM_DESTROY:
		DeleteDC(img.mdc);			// �������f�o�C�X�R���e�L�X�g�̏���
		DeleteObject(hbit);			// �r�b�g�}�b�v�I�u�W�F�N�g�̏���
		PostQuitMessage(0);			// �X���b�h���I�������� 
		break;

	default:
		return DefWindowProc(hwnd, msg, wParam, lParam);
	}
	return 0;
}
void dmsg(LPCWSTR msg) { OutputDebugString(msg); }
//void dmint(int nn) { TCHAR buf[32]; _stprintf_s(buf, 32, _T("%8d\n"), nn); dmsg(buf); }

void win_init(int mode) {
	if(mode==0) PatBlt(img.mdc, 0, 0, img.x_size, img.y_size, BLACKNESS);
	else {
		img.x_size = 640;
		img.y_size = 480;
		gr_init(); // �O���t�B�b�N�E�B���h�E�𐶐�
	}
}
void win_ref(){ InvalidateRect(img.hwnd, NULL, TRUE); }
void SetPixel(int x, int y, DWORD col) {
	SetPixel(img.mdc, x, y, col);
	//InvalidateRect(img.hwnd, NULL, TRUE);
}
void SetPixelB(int x, int y, int dat) {
	DWORD cc;
	unsigned char r, g, b;
	r = (dat & 0xe0); if (r >= 0xe0) r = 0xff;
	g = (dat & 0x1c) << 3; if (g >= 0xe0) g = 0xff;
	b = (dat & 3) << 6; if (b >= 0xc0) b = 0xff;
	cc = (b << 16) | (g << 8) | r;
	SetPixel(img.mdc, x, y, cc);
}

short sqrtxx(short s) {
	short x = s / 2;
	short last_x = 0;
	while (abs(x - last_x)>2) {
		last_x = x;	x = (x + s / x) / 2;
	}
	return x;
}

short fx(short x, short y) {
	short ri;
	x = x - 320;
	y = y - 240;
	ri = sqrtxx(x*x / 20 + y * y / 20);
	while (ri > 50) ri = ri - 50;
	if (ri > 25) ri = 50 - ri;
	return ri*2;
}

void s3d() {
	short x0, y0, w, h, xx, yy, xy, fxh;
	short upper[960], lower[960], i;
	int cc;
	for (i = 0; i<960; i++) {    //�`����W�̏����ݒ�
		upper[i] = -1000; lower[i] = 1000;
	}
	for (yy = 0; yy <= 480; yy += 4) {    //�`�����O����J�n
		for (xx = 0; xx <= 640; xx += 2) {
			fxh = fx(xx, yy);
			xy = 480 - fxh - yy;    //�`�悷����W
			//if (xy>upper[xx + w]) {    //���`��͈͊O�Ȃ�F�ŕ`��
			//	SetPixel(xx + x0, xy, 0x00ff0000);
			//	upper[xx + w] = xy;
			//}
			if (xy<lower[xx + w]) {    //���`��͈͓��Ȃ��/�ΐF�ŕ`��
			cc = 0x0000ff00;// (fxh * 4) | (255 - fxh * 4) * 0x00010100;
				SetPixel(xx, xy, cc);
				lower[xx + w] = xy;
			}
		}
	}
	InvalidateRect(img.hwnd, NULL, TRUE);
}
