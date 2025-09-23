/*
  # Complete University NFC Attendance System Schema

  1. Tables
    - students: Student information and profiles
    - cards: NFC card UIDs linked to students
    - staff: Teachers, security, and admin users
    - courses: Course catalog
    - lectures: Individual lecture sessions
    - gateways: Campus gates and classrooms
    - devices: NFC scanning devices
    - attendance: All attendance records

  2. Security
    - Enable RLS on all tables
    - Add comprehensive policies for all user types
    - Allow public registration for students
    - Allow staff access based on roles

  3. Sample Data
    - Demo staff accounts
    - Sample students with NFC cards
    - Sample courses and lectures
    - Sample gateways and devices
*/

-- Create students table
CREATE TABLE IF NOT EXISTS students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id text UNIQUE NOT NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  faculty text NOT NULL,
  department text NOT NULL,
  photo_url text,
  email text UNIQUE,
  phone text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create cards table
CREATE TABLE IF NOT EXISTS cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_uid text UNIQUE NOT NULL,
  student_id uuid REFERENCES students(id) ON DELETE CASCADE,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create staff table
CREATE TABLE IF NOT EXISTS staff (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id text UNIQUE NOT NULL,
  name text NOT NULL,
  role text NOT NULL CHECK (role IN ('admin', 'teacher', 'security', 'doctor', 'assistant')),
  email text UNIQUE NOT NULL,
  phone text,
  department text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create courses table
CREATE TABLE IF NOT EXISTS courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_code text UNIQUE NOT NULL,
  title text NOT NULL,
  faculty text NOT NULL,
  department text NOT NULL,
  credits integer DEFAULT 3,
  semester text,
  year text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create gateways table
CREATE TABLE IF NOT EXISTS gateways (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  display_name text NOT NULL,
  location text NOT NULL,
  gateway_type text NOT NULL CHECK (gateway_type IN ('gate', 'classroom')),
  capacity integer,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create devices table
CREATE TABLE IF NOT EXISTS devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_code text UNIQUE NOT NULL,
  device_name text NOT NULL,
  owner text,
  device_type text NOT NULL CHECK (device_type IN ('mobile', 'scanner', 'tablet')),
  is_active boolean DEFAULT true,
  last_seen timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create lectures table
CREATE TABLE IF NOT EXISTS lectures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid REFERENCES courses(id) ON DELETE CASCADE,
  staff_id uuid REFERENCES staff(id) ON DELETE CASCADE,
  gateway_id uuid REFERENCES gateways(id) ON DELETE SET NULL,
  title text NOT NULL,
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  status text DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
  max_attendance integer,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create attendance table
CREATE TABLE IF NOT EXISTS attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid REFERENCES students(id) ON DELETE CASCADE,
  card_id uuid REFERENCES cards(id) ON DELETE CASCADE,
  lecture_id uuid REFERENCES lectures(id) ON DELETE CASCADE,
  gateway_id uuid REFERENCES gateways(id) ON DELETE SET NULL,
  device_id uuid REFERENCES devices(id) ON DELETE SET NULL,
  scanned_at timestamptz DEFAULT now(),
  status text DEFAULT 'present' CHECK (status IN ('present', 'late', 'excused')),
  note text,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- RLS Policies for students table
DROP POLICY IF EXISTS "Students can view their own data" ON students;
CREATE POLICY "Students can view their own data"
  ON students FOR SELECT
  TO authenticated
  USING (auth.email() = email);

DROP POLICY IF EXISTS "Staff can view all students" ON students;
CREATE POLICY "Staff can view all students"
  ON students FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email()
    )
  );

DROP POLICY IF EXISTS "Allow student registration" ON students;
CREATE POLICY "Allow student registration"
  ON students FOR INSERT
  TO authenticated
  WITH CHECK (auth.email() = email);

DROP POLICY IF EXISTS "Students can update their own data" ON students;
CREATE POLICY "Students can update their own data"
  ON students FOR UPDATE
  TO authenticated
  USING (auth.email() = email);

-- RLS Policies for cards table
DROP POLICY IF EXISTS "Students can view their own cards" ON cards;
CREATE POLICY "Students can view their own cards"
  ON cards FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM students 
      WHERE students.id = cards.student_id 
      AND students.email = auth.email()
    )
  );

DROP POLICY IF EXISTS "Staff can view all cards" ON cards;
CREATE POLICY "Staff can view all cards"
  ON cards FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email()
    )
  );

DROP POLICY IF EXISTS "Allow card creation" ON cards;
CREATE POLICY "Allow card creation"
  ON cards FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- RLS Policies for staff table
DROP POLICY IF EXISTS "Staff can view their own data" ON staff;
CREATE POLICY "Staff can view their own data"
  ON staff FOR SELECT
  TO authenticated
  USING (email = auth.email());

DROP POLICY IF EXISTS "Admin can view all staff" ON staff;
CREATE POLICY "Admin can view all staff"
  ON staff FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email() 
      AND staff.role = 'admin'
    )
  );

-- RLS Policies for courses table
DROP POLICY IF EXISTS "Anyone can view courses" ON courses;
CREATE POLICY "Anyone can view courses"
  ON courses FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Admin can manage courses" ON courses;
CREATE POLICY "Admin can manage courses"
  ON courses FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email() 
      AND staff.role = 'admin'
    )
  );

-- RLS Policies for lectures table
DROP POLICY IF EXISTS "Anyone can view lectures" ON lectures;
CREATE POLICY "Anyone can view lectures"
  ON lectures FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Teachers can manage their lectures" ON lectures;
CREATE POLICY "Teachers can manage their lectures"
  ON lectures FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email() 
      AND staff.id = lectures.staff_id
    )
  );

DROP POLICY IF EXISTS "Admin can manage all lectures" ON lectures;
CREATE POLICY "Admin can manage all lectures"
  ON lectures FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email() 
      AND staff.role = 'admin'
    )
  );

-- RLS Policies for gateways table
DROP POLICY IF EXISTS "Anyone can view gateways" ON gateways;
CREATE POLICY "Anyone can view gateways"
  ON gateways FOR SELECT
  TO authenticated
  USING (true);

-- RLS Policies for devices table
DROP POLICY IF EXISTS "Anyone can view devices" ON devices;
CREATE POLICY "Anyone can view devices"
  ON devices FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Staff can update devices" ON devices;
CREATE POLICY "Staff can update devices"
  ON devices FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email()
    )
  );

-- RLS Policies for attendance table
DROP POLICY IF EXISTS "Students can view their own attendance" ON attendance;
CREATE POLICY "Students can view their own attendance"
  ON attendance FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM students 
      WHERE students.id = attendance.student_id 
      AND students.email = auth.email()
    )
  );

DROP POLICY IF EXISTS "Staff can view all attendance" ON attendance;
CREATE POLICY "Staff can view all attendance"
  ON attendance FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff 
      WHERE staff.email = auth.email()
    )
  );

DROP POLICY IF EXISTS "Allow attendance recording" ON attendance;
CREATE POLICY "Allow attendance recording"
  ON attendance FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Insert demo staff accounts
INSERT INTO staff (id, staff_id, email, name, role, phone, department) VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'ADMIN001',
    'admin@university.edu',
    'System Administrator',
    'admin',
    '+1-555-0101',
    'IT Department'
  ),
  (
    '00000000-0000-0000-0000-000000000002', 
    'TEACH001',
    'teacher@university.edu',
    'Dr. Sarah Johnson',
    'teacher',
    '+1-555-0102',
    'Computer Science'
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    'SEC001', 
    'security@university.edu',
    'Mike Wilson',
    'security',
    '+1-555-0103',
    'Campus Security'
  ),
  (
    '00000000-0000-0000-0000-000000000004',
    'DOC001', 
    'doctor@university.edu',
    'Dr. Emily Davis',
    'doctor',
    '+1-555-0104',
    'Medical Center'
  ),
  (
    '00000000-0000-0000-0000-000000000005',
    'ASST001', 
    'assistant@university.edu',
    'John Smith',
    'assistant',
    '+1-555-0105',
    'Administration'
  )
ON CONFLICT (email) DO UPDATE SET
  name = EXCLUDED.name,
  role = EXCLUDED.role,
  phone = EXCLUDED.phone,
  department = EXCLUDED.department;

-- Insert sample students
INSERT INTO students (id, student_id, first_name, last_name, faculty, department, email, phone) VALUES
  ('10000000-0000-0000-0000-000000000001', 'STU001', 'Alice', 'Johnson', 'Engineering', 'Computer Science', 'alice.johnson@student.edu', '+1-555-1001'),
  ('10000000-0000-0000-0000-000000000002', 'STU002', 'Bob', 'Smith', 'Engineering', 'Computer Science', 'bob.smith@student.edu', '+1-555-1002'),
  ('10000000-0000-0000-0000-000000000003', 'STU003', 'Carol', 'Davis', 'Business', 'Management', 'carol.davis@student.edu', '+1-555-1003'),
  ('10000000-0000-0000-0000-000000000004', 'STU004', 'David', 'Wilson', 'Medicine', 'General Medicine', 'david.wilson@student.edu', '+1-555-1004')
ON CONFLICT (student_id) DO NOTHING;

-- Insert NFC cards for students
INSERT INTO cards (card_uid, student_id, is_active) VALUES
  ('NFC001234567890', '10000000-0000-0000-0000-000000000001', true),
  ('NFC001234567891', '10000000-0000-0000-0000-000000000002', true),
  ('NFC001234567892', '10000000-0000-0000-0000-000000000003', true),
  ('NFC001234567893', '10000000-0000-0000-0000-000000000004', true)
ON CONFLICT (card_uid) DO NOTHING;

-- Insert sample courses
INSERT INTO courses (id, course_code, title, faculty, department, credits) VALUES
  ('20000000-0000-0000-0000-000000000001', 'CS101', 'Introduction to Programming', 'Engineering', 'Computer Science', 3),
  ('20000000-0000-0000-0000-000000000002', 'CS201', 'Data Structures', 'Engineering', 'Computer Science', 4),
  ('20000000-0000-0000-0000-000000000003', 'BUS101', 'Business Fundamentals', 'Business', 'Management', 3),
  ('20000000-0000-0000-0000-000000000004', 'MED101', 'Anatomy Basics', 'Medicine', 'General Medicine', 5)
ON CONFLICT (course_code) DO NOTHING;

-- Insert sample gateways
INSERT INTO gateways (id, code, display_name, location, gateway_type, capacity) VALUES
  ('30000000-0000-0000-0000-000000000001', 'MAIN_GATE', 'Main Campus Gate', 'Campus Entrance', 'gate', NULL),
  ('30000000-0000-0000-0000-000000000002', 'CS_LAB_1', 'Computer Science Lab 1', 'Engineering Building - Room 101', 'classroom', 30),
  ('30000000-0000-0000-0000-000000000003', 'BUS_HALL', 'Business Hall', 'Business Building - Main Hall', 'classroom', 100),
  ('30000000-0000-0000-0000-000000000004', 'MED_LAB', 'Medical Lab', 'Medical Building - Lab 1', 'classroom', 20)
ON CONFLICT (code) DO NOTHING;

-- Insert sample devices
INSERT INTO devices (id, device_code, device_name, owner, device_type, is_active) VALUES
  ('40000000-0000-0000-0000-000000000001', 'DEV001', 'Main Gate Scanner', 'Campus Security', 'scanner', true),
  ('40000000-0000-0000-0000-000000000002', 'DEV002', 'CS Lab Scanner', 'Dr. Sarah Johnson', 'tablet', true),
  ('40000000-0000-0000-0000-000000000003', 'DEV003', 'Mobile Scanner 1', 'Mike Wilson', 'mobile', true)
ON CONFLICT (device_code) DO NOTHING;

-- Insert sample lectures
INSERT INTO lectures (id, course_id, staff_id, gateway_id, title, start_time, end_time, status) VALUES
  (
    '50000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    'Introduction to Programming - Lecture 1',
    (CURRENT_DATE + INTERVAL '1 day' + TIME '09:00:00'),
    (CURRENT_DATE + INTERVAL '1 day' + TIME '10:30:00'),
    'scheduled'
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    'Data Structures - Lecture 1',
    (CURRENT_DATE + INTERVAL '2 days' + TIME '14:00:00'),
    (CURRENT_DATE + INTERVAL '2 days' + TIME '15:30:00'),
    'scheduled'
  )
ON CONFLICT (id) DO NOTHING;