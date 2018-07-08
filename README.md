
「ＶＴＬ＿ｏｎ＿ＦＰＧＡ」は、ＦＰＧＡ上でＶＴＬ言語を動作させるための実行環境です。  
処理速度向上のために、ＶＴＬ言語を一旦コンパイルしてから実行します。  
例えば、「Ａ＝Ｂ」は「 LDA regA, STA regB」と２命令となり、各々２サイクルなので実行には４サイクル必要です。  
但し、２段パイプライン構成なので３サイクルとなり、１サイクルは20ns(50MHz)なので、60nsで実行完了となります。  
コンパイルはパソコン上もしくはＦＰＧＡ上で行うことが出来ます。  
ＦＰＧＡ上で行う場合はパソコンは不要であり、プログラムを入力後「#=1」を入力する事により実行されます。

１．ＶＴＬ＿ｏｎ＿ＦＰＧＡの各機能を下記に解説しています

　　　　[［その１　VTLと「VTL_on_FPGA」について］](https://qiita.com/hi631/items/30b60e5ae9d50ed6cfa0)

　　　　[［その２　ＧＡＭＥ８６インタープリター］](https://qiita.com/hi631/items/156f5454ffbc22b9c909)

　　　　[［その３　ＦＰＧＡ上のＶＴＬ実行環境］](https://qiita.com/hi631/items/d2c96be05d40fc41c1b7)

　　　　[［その４　ＶＴＬ＿ｏｎ＿ＦＰＧＡコンパイラー］](https://qiita.com/hi631/items/1c292db6fbc2e5b71855)

　　　　[［その５　ＶＴＬ＿ｏｎ＿ＦＰＧＡの拡張ＩＯ］](https://qiita.com/hi631/items/2af8506e070a830349a7)

　　　　[［その６　ＶＴＬ＿ｏｎ＿ＦＰＧＡのシミュレーション］](https://qiita.com/hi631/items/c19fe4a5f513d56b87ab)


２．ＴＤ４ｘ４ 命令一覧  
　ＶＴＬ＿ｏｎ＿ＦＰＧＡは「ＴＤ４ｘ４」(ＶＴＬ専用の独自１６ｂｉｔＣＰＵ)で動作しています。  
　ＣＰＵで実行可能な命令の一覧を下記に示します。たったこれだけの命令で動作しています。  

	---------------+---------------+---------------------------------------------------------------
	命令		ビット構成	動作
	---------------+---------------+---------------------------------------------------------------
	計算 Ra,Rb	0000CCCC	Ra <- RaとRb間で計算  CCCCC=
					___ ADD SUB AND OR_ ^__ MUL SR_ EQU GT  GE  LT  LE  NE  NEG NOP
			0010CCCC	(未定義)
			00010xxx	(未定義)
	LD  Rs,Rx	00m11000	m:条件=0:$18:SP -> A =1:$38:SP <- A
	LD  Rx,Rx	00m11001	m:条件=0:$19:A -> B  =1:$39:A <- B
	XAB Ra,Rb	00011010	$1A レジスタ交換 A <-> B
			00m11xxx	
	IN/OUT		00m11111	M:条件=0:Input($1F)  =1:Output($3F)
	LD  Rx,Vx	01RVVVVV	$40+R+V Rx <- Vx  Rx=regA/B  Vx(変数)=regA/B,A-Z($1B)/%/&/*/_
	ST  Vx,Rx	10RVVVVV	$80+R+V Vx <- Rx
			1100000m	(未定義)
	RTS		1100001b	$C2+b(0)
	LDM Ra,(Ra)	1100010b	$C4+b メモリ読み出し　b:バイト数=0:1byte  =1:2byte
	LDM (Ra),Rb	1100011b	$C6+b メモリ書き込み　
	PE/PO (SP)	11001mxx	$C8+m regAと(SP+xx*2)でデータ交換　m:条件=0:Read  =1:Write
	PUSH/POP Rx	1110mxxx	$Ex m:条件=0:$E0:POP  =1:$E8:PUSH xxx=0:regA 1:regB 2-7:A-F
	JPx xxyy	1101JJJJ+xx+yy	$Dx 条件成立時ジャンプ　JJJJ=0($D0):JZ =1($D1)JNZ
	JPx xxyy	11011JJJ+xx+yy	$Dx($D6/D7/F6/F7除外) 条件ジャンプ JJJ=0:$D8:JZ 1:$D9:JNZ
			11111xxx+xx+yy	$Fx($D6/D7/F6/F7除外)
	JSR		11011110+xx+yy	$D6/$DE
	JMP		11111110+xx+yy	$F6/$FE
	LDI Rx,xxyy	11R1b111+xx+yy	Rx <- #xxxx b:バイト数 =1:$DF/$FF(2byte) =0:$D7/$F7(1byte)
	---------------+---------------+---------------------------------------------------------------


３．ＶＴＬ＿ｏｎ＿ＦＰＧＡの文法  
　ＶＴＬ言語の文法を下記に示します。  
  ※一部実装していない命令が有ります( + | ' | #)。

    <行番号>   1 ? 32767
    <10進定数> 0 ? 65535
    <16進定数> $0000 ? $FFFF
    <文字定数> "文字"
    <変数名>   A ? Z または冗長形(ABC等 先頭1文字が有効)
    <1バイト配列> ::= 変数名 ( <式> )
                      変数の値 + 2 * 式の値 のアドレスの内容を値とする．
    <2バイト配列> ::= 変数名 : <式> )
                      変数の値 + 式の値 のアドレスの内容を値とする．
    <定数> ::= <10進定数> | <16進定数> | <文字定数>
    <変数> ::= <変数名> | <1バイト配列> | <2バイト配列>
    <式> ::= <項> | <項> <二項演算子> <項>
    <項> ::= <定数> | <変数> | <配列> |（ <式> ）| <単項演算子> <項>
    <二項演算子> ::= + | - | * | / | = | <> | < | > | <= | >=
                    比較演算 は 真:1, 偽:0の値を取る．
    <単項演算子> ::= - | + | % | ' | #
                     + は絶対値, % は直前に実行した除算の余り,
                     ' は乱数, #は否定．
    <行> ::= <行番号> スペース <文> [ 空白 <文> ] 改行
             | <行番号> スペース以外の文字 コメント 改行

    <文>
        <変数>=<項>     変数への代入
        #=<項>            <項>の値の行番号の文にジャンプ(GOTO)
                          行番号がなければ行番号より大きい最初の行へジャンプ
        #=-1              プログラムの終了(END)
        !=<項>            <項>の値の行番号のサブルーチンへジャンプ(GOSUB)
        ]                 サブルーチンから戻る(RETURN)
        ;=式              式の値が真の場合は次の文に進み，
                          偽の場合は次の行を実行．
        @                 DO
        @=(式)            UNTIL
        変数=初期値,ステップ FOR
        @=式              NEXT
        /                 改行出力
        "文字列"          文字列出力
        ?=<項>            <項>の結果を数値出力 左詰め
        ??=<項>           <項>の結果を数値出力 16進4桁
        ?$=<項>           <項>の結果の下位1バイトを数値出力 16進2桁
        ?(n)=<項>         <項>の値の数値出力 n桁で右詰め
        $=<項>            <項>の値の下位バイトを文字コードとする１文字を出力
        .=<項>            <項>の値の下位バイトの数だけ空白を出力
        '=<項>            <項>の値で乱数シードを設定
        <変数>=?          10進数値を入力して変数に代入
        <変数>=$          1文字を入力して変数に代入
