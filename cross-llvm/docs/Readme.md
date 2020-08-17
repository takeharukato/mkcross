# LLVM開発環境構築スクリプト

## はじめに

  本スクリプトは, LLVM開発環境をX86-64で動作するRHEL7環境上に構築する機能を提供します。
  本スクリプトは, 開発版のLLVMリポジトリから以下のツールを構築します。

  * clang ( Cコンパイラ )
  * clang++ (C++コンパイラ)
  * llvm付属ツール (アセンブラなど)
  * lld (リンカ)
  * lldb (デバッガ)
  * z3 (定理証明器)
  * cmake (ビルド支援ツール)
  * ninja  (ビルド支援ツール)

## ファイル構成

1. docs/Readme.md       本ファイルです。

2. env/llvm-env.sh   LLVMコンパイラを構築するための定義ファイルです。
                     各種ツールの版数とダウンロード元URLを定義しています。

3. scripts/llvm-build.sh コンパイラや各種ツールを生成するスクリプト本体です。

4. scripts/gen-llvm-env.sh LLVMコンパイラへのパスを設定するスクリプトを
    生成します。${HOME}/env/ディレクトリが存在する場合は, ${HOME}/env/ディ
    レクトリに, `llvm-current-env.sh`
	という名前のシェルスクリプトを生成します。各スクリプトをBシェルの
	sourceコマンドで読み込むことで, 環境変数`PATH`と環境変数`LD_LIBRARY_PATH`が設定
    されます。変更前の環境変数`PATH`と環境変数`LD_LIBRARY_PATH`の設定
    値は, それぞれ,	環境変数`OLD\_PATH`, `OLD_LD_LIBRARY_PATH`に保存されます。
	また, `${HOME}/Modules`というディレクトリが存在する場合は, `${HOME}/Modules`
	に`CURRENT-LLVM`という名前でEnvironment Modules用の環境
    設定ファイルを生成します。

5. data/gud.el      emacsでLLVMを使用するためのemacs lispファイルです
                     (Grand Unified Debugger mode)。
					本スクリプトは, 最新版のgud.elをdownloads
					ディレクトリにダウンロードします。
					data/gud.elまたはdownloads/gud.elを
                    load-path内にあるディレクトリに配置し, .emacs
		            に以下を追記します。

```
(load-library "gud") ;; Grand Unified Debugger mode
```

## 構築手順

cross-llvmディレクトリ(本ファイルのあるディレクトリの一つ上のディレクトリ)に移り, 
以下のコマンドを実行します(B shellでの実行の場合を想定しています)。

```
/bin/sh ./scripts/llvm-build.sh ./env/環境定義ファイル| tee build.log 2>&1     
```

例:
```
/bin/sh ./scripts/llvm-build.sh ./env/llvm-env.sh|tee build.log 2>&1
```

構築が終わると, `${HOME}/cross/llvm/日付`ディレクトリにツール・ライブ
ラリがインストールされます。 最後に構築したコンパイル環境へのシンボリックリンクが
`${HOME}/cross/llvm/current`として生成されます。 

`${HOME}/cross/llvm/current/bin`を環境変数`PATH`に追加することで, LLVM
コンパイル環境を利用可能です。 

