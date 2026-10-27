/// Supabase 연결 값. 둘 다 **공개해도 되는 값**(anon key 는 RLS 로 보호된다).
/// service_role 키는 절대 여기에 넣지 않는다.
///
/// 채우는 법: Supabase 대시보드 → Project Settings → API → "Project URL", "anon public".
/// 비어 있으면 Supabase 동기화는 꺼지고 Firestore 만 쓴다.
const supabaseUrl = '';
const supabaseAnonKey = '';

bool get supabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
