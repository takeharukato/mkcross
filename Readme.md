# クロス開発環境構築スクリプト

クロス開発環境をX86-64で動作するRHEL7環境上に構築するためのシェルスクリプトです。
  
1. cross-gcc  GNU Compiler Collectionを用いたクロスコンパイル環境構築スクリプトを格納したディレクトリです。
1. cross-llvm LLVM言語基盤を用いたクロスコンパイル環境構築スクリプトを格納したディレクトリです。
1. common/scripts/do-all.sh     全てのアーキテクチャ向けのクロス環境生
   成処理を順番に実行するスクリプトです。 

gccによるクロスコンパイラ生成スクリプト, LLVM言語基盤生成スクリプトに
使用法は, `cross-gcc`, `cross-llvm`の各ディレクトリ配下の
docs/Readme.mdファイルを参照ください。

# クロスコンパイラ生成手順

対応している全アーキテクチャ向けのコンパイラを生成する場合は, 以下を実行します。

```
/bin/sh ./common/scripts/do-all.sh
```

`CPU名-Linux-build.log`, `CPU名-ELF-build.log`, および
`LLVM-build.log` にLinuxターゲット用コンパイラ, ELFターゲット用コンパ
イラ, LLVM言語基盤構築時のログが残されます。

構築が終わると, 以下のディレクトリにツール・ライブラリがインストールされます。

* Linux環境用  ${HOME}/cross/gcc/アーキテクチャ名/日付
* ELF環境用    ${HOME}/cross/gcc-elf/アーキテクチャ名/日付
* LLVM言語基盤 ${HOME}/cross/llvm/日付

最後に構築したコンパイル環境へのシンボリックリンクが以下のように生成されます。

* Linux環境用 ${HOME}/cross/gcc/アーキテクチャ名/current
* ELF環境用 ${HOME}/cross/gcc-elf/アーキテクチャ名/current
* LLVM言語基盤 ${HOME}/cross/llvm/current

`${HOME}/cross/gcc/アーキテクチャ名/current/bin`,
`${HOME}/cross/gcc-elf/アーキテクチャ名/current/bin`,
`${HOME}/cross/llvm/current/bin` を環境変数`PATH`に追加することで, ク
ロスコンパイル環境を利用可能です。

