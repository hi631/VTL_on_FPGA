#include "stdafx.h"
#include <windows.h>
#include <stdio.h>
#include "winwind.h"
IMG00 img;
DWORD th_Proc();
LRESULT CALLBACK grProc(HWND, UINT, WPARAM, LPARAM);
static LPDWORD lpPixel;

//	グラフィックウィンドウの生成，メッセージループ用スレッドの起動
void gr_init()
{
	img.hi = (HINSTANCE)GetWindowLong(HWND_DESKTOP, GWL_HINSTANCE);
	WNDCLASSEX	wc;					//　新しくつくるウインドクラス
	memset(&wc, 0, sizeof(WNDCLASSEX));
	wc.cbSize = sizeof(WNDCLASSEX);
	wc.lpfnWndProc = grProc;				// このクラスの持つウインドプロシージャ
	wc.hInstance = img.hi;
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
	wc.lpszClassName = TEXT("DOS_Win");				// このクラスの名前
	if (!RegisterClassEx(&wc)) return;				// ウィンドクラスの登録
	DWORD tid;
	img.hwnd = 0;
	CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)th_Proc,
		NULL, 0, &tid);					// メッセージループのスレッドを起動	
	while (!img.hwnd);					// ウィンドウが表示されるのを待つ
}

//　メッセージループのためのスレッド
DWORD th_Proc()
{
	int sm0 = GetSystemMetrics(SM_CYCAPTION);
	int sm1 = GetSystemMetrics(SM_CXFIXEDFRAME);		// WS_OVRELAPPの場合、枠の太さは
	int sm2 = GetSystemMetrics(SM_CYFIXEDFRAME);		// SM_C?FIXEDFRAMEになる
	img.hwnd = CreateWindow(TEXT("DOS_Win"),			// クラスの名前
		TEXT("DOS_Win"),
		WS_OVERLAPPED | WS_VISIBLE,	// ウィンドウの属性
		CW_USEDEFAULT, CW_USEDEFAULT,	// 位置は指定しない
		img.x_size + sm1 * 2, 		// 描画サイズからウィンドウの大きさを計算
		img.y_size + sm0 + sm2 * 2,
		HWND_DESKTOP,			// 親はディスクトップ
		NULL, img.hi, NULL);	// pimgをウィンドウプロシージャに渡す 
	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)){
		DispatchMessage(&msg);
	}
	return 0;
}

//　ウィンドウプロシージャ，描画オブジェクトの準備と再描画を行う
LRESULT CALLBACK grProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	static HBITMAP hbit;

	switch (msg){
	case WM_CREATE:{
		HDC hdc = GetDC(hwnd);
		// ウィンドウと同じ仮想画面を作る
		img.mdc = CreateCompatibleDC(hdc);
		hbit = CreateCompatibleBitmap(hdc, img.x_size, img.y_size);
		SelectObject(img.mdc, hbit);
		PatBlt(img.mdc, 0, 0, img.x_size, img.y_size, BLACKNESS);	// 仮想画面のクリア
		ReleaseDC(hwnd, hdc);
		break;
	}
	case WM_PAINT:{
		PAINTSTRUCT ps;
		BeginPaint(hwnd, &ps);
		//　仮想画面からのコピー	
		BitBlt(ps.hdc, 0, 0, img.x_size, img.y_size, img.mdc, 0, 0, SRCCOPY);
		EndPaint(hwnd, &ps);
		break;
	}
	case WM_DESTROY:
		DeleteDC(img.mdc);			// メモリデバイスコンテキストの消去
		DeleteObject(hbit);			// ビットマップオブジェクトの消去
		PostQuitMessage(0);			// スレッドを終了させる 
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
		gr_init(); // グラフィックウィンドウを生成
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
	for (i = 0; i<960; i++) {    //描画座標の初期設定
		upper[i] = -1000; lower[i] = 1000;
	}
	for (yy = 0; yy <= 480; yy += 4) {    //描画を手前から開始
		for (xx = 0; xx <= 640; xx += 2) {
			fxh = fx(xx, yy);
			xy = 480 - fxh - yy;    //描画する座標
			//if (xy>upper[xx + w]) {    //既描画範囲外なら青色で描画
			//	SetPixel(xx + x0, xy, 0x00ff0000);
			//	upper[xx + w] = xy;
			//}
			if (xy<lower[xx + w]) {    //既描画範囲内なら赤/緑色で描画
			cc = 0x0000ff00;// (fxh * 4) | (255 - fxh * 4) * 0x00010100;
				SetPixel(xx, xy, cc);
				lower[xx + w] = xy;
			}
		}
	}
	InvalidateRect(img.hwnd, NULL, TRUE);
}
