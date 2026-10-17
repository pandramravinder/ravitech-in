-- ====================================================================
-- RAVITECH LEARNING PLATFORM - SUPABASE DATABASE SCHEMA
-- Execute this SQL script in the Supabase SQL Editor
-- ====================================================================

-- 1. Profiles table (extends Supabase auth.users)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text not null,
  mobile_number text,
  selected_course text,
  role text default 'student' check (role in ('student', 'admin', 'instructor')),
  account_status text default 'Active' check (account_status in ('Active', 'Pending', 'Suspended')),
  avatar_url text,
  headline text,
  bio text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.profiles enable row level security;

-- Student RLS: Students can view their own profile; Admins can view all profiles
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Admins can view all profiles" on public.profiles
  for select using (
    exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin')
  );

create policy "Users can insert their own profile." on public.profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on public.profiles
  for update using (auth.uid() = id);

-- 2. Courses table
create table if not exists public.courses (
  id text primary key,
  title text not null,
  slug text unique not null,
  category text not null,
  short_desc text not null,
  description text not null,
  instructor_name text not null,
  instructor_title text not null,
  instructor_avatar text,
  level text default 'Beginner' check (level in ('Beginner', 'Intermediate', 'Advanced', 'All Levels')),
  duration text not null,
  price numeric default 0,
  original_price numeric default 0,
  rating numeric default 4.8,
  total_ratings integer default 0,
  students_enrolled integer default 0,
  thumbnail_url text not null,
  certificate_eligible boolean default true,
  learning_objectives jsonb default '[]'::jsonb,
  prerequisites jsonb default '[]'::jsonb,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.courses enable row level security;
create policy "Courses are viewable by everyone" on public.courses for select using (true);
create policy "Admins can manage courses" on public.courses for all using (
  exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin')
);

-- 3. Modules & Lessons
create table if not exists public.modules (
  id text primary key,
  course_id text references public.courses(id) on delete cascade,
  title text not null,
  order_index integer not null default 0
);

create table if not exists public.lessons (
  id text primary key,
  module_id text references public.modules(id) on delete cascade,
  course_id text references public.courses(id) on delete cascade,
  title text not null,
  duration text not null,
  video_url text,
  content_text text,
  order_index integer not null default 0,
  resources jsonb default '[]'::jsonb,
  quiz jsonb default '[]'::jsonb
);

alter table public.modules enable row level security;
create policy "Modules are viewable by everyone" on public.modules for select using (true);

alter table public.lessons enable row level security;
create policy "Lessons are viewable by everyone" on public.lessons for select using (true);

-- 4. Enrollments
create table if not exists public.enrollments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  course_id text references public.courses(id) on delete cascade not null,
  enrolled_at timestamp with time zone default timezone('utc'::text, now()) not null,
  progress_percent integer default 0,
  last_lesson_id text,
  status text default 'in_progress' check (status in ('in_progress', 'completed')),
  unique(user_id, course_id)
);

alter table public.enrollments enable row level security;
create policy "Users can view their enrollments" on public.enrollments
  for select using (auth.uid() = user_id);
create policy "Admins can view all enrollments" on public.enrollments
  for select using (
    exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin')
  );
create policy "Users can insert their own enrollment" on public.enrollments
  for insert with check (auth.uid() = user_id);
create policy "Users can update their own enrollment" on public.enrollments
  for update using (auth.uid() = user_id);

-- 5. Lesson Progress
create table if not exists public.lesson_progress (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  course_id text references public.courses(id) on delete cascade not null,
  lesson_id text references public.lessons(id) on delete cascade not null,
  completed boolean default false,
  completed_at timestamp with time zone default timezone('utc'::text, now()),
  unique(user_id, course_id, lesson_id)
);

alter table public.lesson_progress enable row level security;
create policy "Users can view and update their lesson progress" on public.lesson_progress
  for all using (auth.uid() = user_id);

-- 6. Assignment Submissions
create table if not exists public.assignment_submissions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  course_id text references public.courses(id) on delete cascade not null,
  lesson_id text not null,
  assignment_title text not null,
  project_url text not null,
  notes text,
  grade text default 'Pending' check (grade in ('Pending', 'Passed', 'Needs Revision')),
  feedback text,
  submitted_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.assignment_submissions enable row level security;
create policy "Users can view and create assignment submissions" on public.assignment_submissions
  for all using (auth.uid() = user_id);
create policy "Admins can view and grade all assignments" on public.assignment_submissions
  for all using (
    exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin')
  );

-- 7. Certificates
create table if not exists public.certificates (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  course_id text references public.courses(id) on delete cascade not null,
  certificate_number text unique not null,
  issued_at timestamp with time zone default timezone('utc'::text, now()) not null,
  grade text default 'Distinction'
);

alter table public.certificates enable row level security;
create policy "Public certificates viewable" on public.certificates for select using (true);
