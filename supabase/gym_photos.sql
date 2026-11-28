-- 기구 사진 공유: Supabase 대시보드 → SQL Editor 에서 한 번 실행.
-- 경로 {찍은 사람 uid}/{기구 id}.jpg. 올리기·고치기·지우기는 내 폴더만, 보기는 로그인한 앱 사용자만.
-- (schema.sql 의 auth_uid() 함수가 먼저 있어야 한다)

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gym-photos', 'gym-photos', false, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists gym_photos_read on storage.objects;
drop policy if exists gym_photos_insert on storage.objects;
drop policy if exists gym_photos_update on storage.objects;
drop policy if exists gym_photos_delete on storage.objects;

create policy gym_photos_read on storage.objects for select
  using (bucket_id = 'gym-photos' and public.auth_uid() is not null);

create policy gym_photos_insert on storage.objects for insert
  with check (bucket_id = 'gym-photos' and (storage.foldername(name))[1] = public.auth_uid());

create policy gym_photos_update on storage.objects for update
  using (bucket_id = 'gym-photos' and (storage.foldername(name))[1] = public.auth_uid())
  with check (bucket_id = 'gym-photos' and (storage.foldername(name))[1] = public.auth_uid());

create policy gym_photos_delete on storage.objects for delete
  using (bucket_id = 'gym-photos' and (storage.foldername(name))[1] = public.auth_uid());
