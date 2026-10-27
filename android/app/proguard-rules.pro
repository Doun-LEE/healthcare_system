# google_mlkit_text_recognition 플러그인은 중국어·일본어·힌디어 모델도 참조하지만
# 앱에는 라틴·한국어만 넣는다. 없는 클래스 경고를 무시해야 R8(릴리스 축소)이 통과한다.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
