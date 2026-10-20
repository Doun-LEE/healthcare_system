@echo off
rem 노트북에서 Chrome으로 앱 실행 (핫 리로드: 터미널에서 r, 완전 재시작: R, 종료: q)
rem 한글 경로 문제를 피하려고 C:\dev\fitroutine 정션에서 실행한다.
if not exist C:\dev\fitroutine (
  mklink /J C:\dev\fitroutine "%~dp0."
)
cd /d C:\dev\fitroutine
C:\dev\flutter\bin\flutter run -d chrome
