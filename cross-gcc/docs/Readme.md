# gccクロス開発環境構築スクリプト

## はじめに
  gcc開発環境をX86-64で動作するRHEL7環境上に構築するためのシェルスクリプトです。
      
1. docs/Readme.md    本ファイルです。

2. env/              コンパイラを構築するための定義ファイルです。
   		     以下を定義しています（カッコ内は, シェル変数名)。

     * ターゲットCPU名 (TARGET_CPU)
     * カーネル構築時のアーキテクチャ名(KERN_ARCH)
     * QEMUのCPU名(QEMU_CPU)
     * ホスト種別(HOST)
     * ライブラリの格納先ディレクトリ名(_LIB)
     * 各種ツールの版数(GMAKE, GTARなど)
     * ダウンロード元URL(DOWNLOAD_URLS)

     各CPUごとに以下のファイルを読み込みます。
		     
     * aarch64-env.sh  AArch64用
     * armhw-env.sh    ハードウエア浮動小数点演算器搭載 32bit Arm用
     * i686-env.sh     IA32用
     * riscv32-env.sh  RISC-V 32bit用
     * riscv64-env.sh  RISC-V 64bit用
     * x64-env.sh      X64用
                     

3. scripts/     クロスコンパイラや各種ツールを生成するスクリプト本体を
                格納するディレクトリです。

    * build.sh      Linux環境向けのクロスコンパイラや各種ツールを生成します。
    * build-elf.sh  ベアメタル開発向けELFバイナリ向けのクロスコンパイ
      ラや各種ツールを生成します。 
    * do-all.sh     上記の全てのアーキテクチャ向けのクロス環境生成処理
      を順番に実行します。 
    * gen-cross-env.sh クロスコンパイラへのパスを設定するスクリプトを
    生成します。${HOME}/env/ディレクトリが存在する場合は, ${HOME}/env/ディ
    レクトリに, `CPU名-ツールチェインタイプ-env.sh`
	という名前のシェルスクリプトを生成します。各スクリプトをBシェルの
	sourceコマンドで読み込むことで, 環境変数`PATH`と環境変数`LD_LIBRARY_PATH`が設定
    されます。変更前の環境変数`PATH`と環境変数`LD_LIBRARY_PATH`の設定
    値は, それぞれ,	環境変数`OLD\_PATH`, `OLD_LD_LIBRARY_PATH`に保存されます。
	さらにターゲットCPUに合わせて, 以下の環境変数を設定します。
	* CPU gccのターゲットCPU名を設定します。
	* QEMU_CPU QEmuのCPU名を設定します。
	* CROSS_COMPILE Linuxなどでクロスコンパイラを指定する場合のコンパ
    イラプレフィクス名を設定します。
	* GDB_COMMAND クロスgdbのコマンド名を設定します。
	* QEMU     QEmuのシステムエミュレータのコマンド名を設定します。
	
	また, `${HOME}/Modules`というディレクトリが存在する場合は, `${HOME}/Modules`
	に`CPU名-ツールチェインタイプ-GCC`という名前でEnvironment Modules用の環境
    設定ファイルを生成します。
	
4. data/gud.el      emacsでLLVMを使用するためのemacs lispファイルです
                     (Grand Unified Debugger mode)。
                     load-path内にあるディレクトリに配置し, .emacs
		     に以下を追記します。

```
(load-library "gud") ;; Grand Unified Debugger mode
```

5. patches/           クロスコンパイル環境構築に必要なパッチを格納しています.

   * patches/cross/glibc/install-lib-all.patch 
       クロスコンパイラ作成のために一時的にglibcのライブラリのみを構築し, 
      glibc付属のコマンドの構築とインストールを行わないようにする必要が
      あります。
        install-lib-all.patchは, glibcのライブラリのみを構築とインストール
      を行うためのmakeターゲットをglibcのMakefile(Makerulesファイル）に
      追加するためのパッチです。

   * patches/elfutils/elfutils-portability.patch
        RHELのelfutilsの修正を取込むためのパッチです。
      RHEL5環境でのコンパイル時に, ライブラリの関数宣言がないことから
      elfutilsのコンパイル時に警告がだされmakeが異常終了するため,
      警告を無視する標準オプション(--disable-werror)を追加するための
      修正をelfutilsに追加するパッチです。

   * patches/elfutils/elfutils-robustify.patch
     RHELのelfutilsの修正を取込むためのパッチです。
     RHELでの障害修正を取込むパッチです。

   * patches/gdb/gdb-8.2-qemu-x86-64.patch
     QEMUターゲットをgdbでリモートデバッグする際に発生する
     ``Remote 'g' packet reply is too long``
     エラーを回避するためのパッチです。

## 構築されるツール
   本スクリプトを使用することで以下のツール・ライブラリがコンパイルされます。

   * binutils (アセンブラ, リンカなど)
   * gcc (Cコンパイラ, C++コンパイラ, リンク時最適化ツール )
   * C標準ライブラリ
    * GNU libc ( Linux用クロスコンパイラの場合 )
    * Newlib   ( ELF用クロスコンパイラの場合 )
   * GNU Debugger 
   * QEMU エミュレータ (ユーザランド, システムシミュレータ) 
   * EDK2 UEFI ファームウエア (X64, AArch64ターゲットの場合)

## 構築手順
cross-gccディレクトリ(本ファイルのあるディレクトリの一つ上のディレクトリ)に移り, 
以下のコマンドを実行すると, Linux用のクロス環境が構築できます
(B shellでの実行の場合を想定しています)。

```
/bin/sh ./scripts/build.sh ./env/環境定義ファイル| tee build.log 2>&1
```

ELFターゲットの場合は以下を実行します。

```
/bin/sh ./scripts/build-elf.sh ./env/環境定義ファイル| tee build.log 2>&1
```

例: Linux用AArch64ターゲット向けクロスコンパイラを作成する場合
```
/bin/sh ./scripts/build.sh ./env/aarch64-env.sh| tee build.log 2>&1
```

例: ELF(ベアメタル)用AArch64ターゲット向けクロスコンパイラを作成する場合
```
/bin/sh ./scripts/build-elf.sh ./env/aarch64-env.sh| tee build.log 2>&1
```

対応している全アーキテクチャ向けのコンパイラを生成する場合は, 以下を実行します。

```
/bin/sh ./scripts/do-all.sh 
```
`CPU名-Linux-build.log` および `CPU名-ELF-build.log` にLinuxターゲット用コンパイラ, ELFターゲット用コンパイラ構築時のログが残されます。

構築が終わると, 以下のディレクトリにツール・ライブラリがインストールされます。

* Linux環境用 ${HOME}/cross/gcc/アーキテクチャ名/日付
* ELF環境用 ${HOME}/cross/gcc-elf/アーキテクチャ名/日付

最後に構築したコンパイル環境へのシンボリックリンクが以下のように生成されます。

* Linux環境用 ${HOME}/cross/gcc/アーキテクチャ名/current
* ELF環境用 ${HOME}/cross/gcc-elf/アーキテクチャ名/current

`${HOME}/cross/gcc/アーキテクチャ名/current/bin`, `${HOME}/cross/gcc-elf/アーキテクチャ名/current/bin` を環境変数`PATH`に追加することで, クロスコンパイル環境を利用可能です。





