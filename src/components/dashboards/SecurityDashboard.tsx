import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Scan, User, Clock, CheckCircle, AlertCircle } from 'lucide-react';

interface Student {
  id: string;
  student_id: string;
  first_name: string;
  last_name: string;
  faculty: string;
  department: string;
  photo_url: string | null;
}

interface RecentEntry {
  id: string;
  scanned_at: string;
  student: Student;
  status: string;
}

export default function SecurityDashboard() {
  const [cardUid, setCardUid] = useState('');
  const [scannedStudent, setScannedStudent] = useState<Student | null>(null);
  const [recentEntries, setRecentEntries] = useState<RecentEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchRecentEntries();
  }, []);

  const fetchRecentEntries = async () => {
    try {
      const today = new Date().toISOString().split('T')[0];
      const { data, error } = await supabase
        .from('attendance')
        .select(`
          *,
          students:student_id (*)
        `)
        .is('lecture_id', null) // Only gate entries
        .gte('scanned_at', `${today}T00:00:00`)
        .order('scanned_at', { ascending: false })
        .limit(10);

      if (error) throw error;

      setRecentEntries(data.map(entry => ({
        ...entry,
        student: entry.students as Student
      })));
    } catch (error) {
      console.error('Error fetching recent entries:', error);
    }
  };

  const handleScan = async () => {
    if (!cardUid.trim()) {
      setError('Please enter a card UID');
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');
    setScannedStudent(null);

    try {
      // Simulate NFC scan API call
      const response = await fetch('/api/scan', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          card_uid: cardUid,
          device_code: 'DEV001', // Main gate scanner
          gateway_code: 'MAIN_GATE',
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Scan failed');
      }

      setScannedStudent(result.student);
      setSuccess(`Entry recorded for ${result.student.first_name} ${result.student.last_name}`);
      setCardUid('');
      await fetchRecentEntries(); // Refresh the list
    } catch (error) {
      // Fallback: try to find student directly for demo purposes
      try {
        const { data: card } = await supabase
          .from('cards')
          .select(`
            *,
            students (*)
          `)
          .eq('card_uid', cardUid)
          .single();

        if (card && card.students) {
          const student = card.students as Student;
          
          // Record attendance directly
          const { error: attendanceError } = await supabase
            .from('attendance')
            .insert([
              {
                student_id: student.id,
                card_id: card.id,
                gateway_id: 'gateway_id_placeholder', // Would be actual gateway ID
                device_id: 'device_id_placeholder', // Would be actual device ID
                status: 'present'
              }
            ]);

          if (!attendanceError) {
            setScannedStudent(student);
            setSuccess(`Entry recorded for ${student.first_name} ${student.last_name}`);
            setCardUid('');
            await fetchRecentEntries();
          } else {
            throw new Error('Failed to record attendance');
          }
        } else {
          throw new Error('Card not found');
        }
      } catch (fallbackError) {
        setError('Card not found or scan failed');
      }
    } finally {
      setLoading(false);
    }
  };

  const quickScan = (uid: string) => {
    setCardUid(uid);
  };

  const formatTime = (timestamp: string) => {
    return new Date(timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div className="max-w-4xl mx-auto p-4 space-y-6">
      {/* NFC Scan Section */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <div className="text-center mb-6">
          <div className="mx-auto h-16 w-16 bg-orange-100 rounded-full flex items-center justify-center mb-4">
            <Scan className="h-8 w-8 text-orange-600" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900">Campus Gate Scanner</h2>
          <p className="text-gray-600">Scan student NFC cards for campus entry</p>
        </div>

        <div className="max-w-md mx-auto space-y-4">
          <div>
            <label htmlFor="cardUid" className="block text-sm font-medium text-gray-700 mb-2">
              Card UID
            </label>
            <input
              id="cardUid"
              type="text"
              placeholder="Enter or tap NFC card UID"
              value={cardUid}
              onChange={(e) => setCardUid(e.target.value)}
              className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              onKeyPress={(e) => e.key === 'Enter' && handleScan()}
            />
          </div>

          <button
            onClick={handleScan}
            disabled={loading}
            className="w-full bg-orange-600 hover:bg-orange-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Scanning...' : 'Scan Card'}
          </button>

          {/* Demo Cards */}
          <div className="border-t pt-4">
            <p className="text-sm text-gray-600 mb-2">Demo Cards:</p>
            <div className="grid grid-cols-2 gap-2">
              {['NFC001234567890', 'NFC001234567891', 'NFC001234567892', 'NFC001234567893'].map((uid) => (
                <button
                  key={uid}
                  onClick={() => quickScan(uid)}
                  className="p-2 text-xs bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  {uid.slice(-4)}
                </button>
              ))}
            </div>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center gap-3">
              <AlertCircle className="h-5 w-5 text-red-500 flex-shrink-0" />
              <p className="text-red-700 text-sm">{error}</p>
            </div>
          )}

          {success && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4 flex items-center gap-3">
              <CheckCircle className="h-5 w-5 text-green-500 flex-shrink-0" />
              <p className="text-green-700 text-sm">{success}</p>
            </div>
          )}
        </div>
      </div>

      {/* Scanned Student Profile */}
      {scannedStudent && (
        <div className="bg-white rounded-xl shadow-sm p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Student Profile</h3>
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 bg-blue-100 rounded-full flex items-center justify-center">
              {scannedStudent.photo_url ? (
                <img
                  src={scannedStudent.photo_url}
                  alt={`${scannedStudent.first_name} ${scannedStudent.last_name}`}
                  className="h-16 w-16 rounded-full object-cover"
                />
              ) : (
                <User className="h-8 w-8 text-blue-600" />
              )}
            </div>
            <div>
              <h4 className="text-xl font-semibold text-gray-900">
                {scannedStudent.first_name} {scannedStudent.last_name}
              </h4>
              <p className="text-gray-600">ID: {scannedStudent.student_id}</p>
              <p className="text-sm text-gray-500">
                {scannedStudent.faculty} - {scannedStudent.department}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Recent Entries */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        <div className="flex items-center gap-2 mb-4">
          <Clock className="h-5 w-5 text-gray-600" />
          <h3 className="text-lg font-semibold text-gray-900">Today's Entries</h3>
        </div>

        <div className="space-y-3">
          {recentEntries.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No entries today</p>
          ) : (
            recentEntries.map((entry) => (
              <div key={entry.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 bg-blue-100 rounded-full flex items-center justify-center">
                    <User className="h-5 w-5 text-blue-600" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">
                      {entry.student.first_name} {entry.student.last_name}
                    </p>
                    <p className="text-sm text-gray-500">{entry.student.student_id}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium text-gray-900">
                    {formatTime(entry.scanned_at)}
                  </p>
                  <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                    entry.status === 'present' 
                      ? 'bg-green-100 text-green-800'
                      : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {entry.status}
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}