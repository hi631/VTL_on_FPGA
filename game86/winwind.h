// グラフィック用ウィンドウのデータをまとめた構造体
typedef struct{
	HINSTANCE			hi;			// インスタンスハンドル
	int				x_size;		// グラフィック画面の大きさ
	int				y_size;
	HDC				mdc;		// メモリデバイスコンテキスト
	HWND				hwnd;		// 自分のウィンドウハンドル
} IMG00;
// 別スレッドを起動し別スレッドでウィンドウを生成する
void gr_init();
