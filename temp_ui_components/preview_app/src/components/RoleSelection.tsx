import { useState } from 'react';
import { doc, setDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Users, Briefcase, ChevronRight } from 'lucide-react';
import Logo from './Logo';

export default function RoleSelection() {
  const [loading, setLoading] = useState<string | null>(null);

  const handleSelectRole = async (role: 'family' | 'caregiver') => {
    const user = auth.currentUser;
    if (!user) return;
    
    setLoading(role);
    try {
      await setDoc(doc(db, 'users', user.uid), {
        role: role
      }, { merge: true });
      // App.tsx onSnapshot will handle routing automatically once this completes
    } catch (error) {
      console.error("Error setting role:", error);
      setLoading(null);
    }
  };

  return (
    <div className="min-h-[80vh] flex flex-col items-center justify-center p-4">
      <div className="mb-12 flex flex-col items-center">
        <Logo className="w-16 h-16 text-[#5A6844] mb-6 shadow-sm" variant="solid-field" />
        <h1 className="font-serif text-4xl md:text-5xl font-bold text-[#2D3325] text-center mb-4">
          Welcome to GoldenCare
        </h1>
        <p className="text-[#5C6450] text-lg text-center max-w-lg">
          To personalize your experience, please tell us how you'll be using the platform.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-4xl">
        
        {/* Family Card */}
        <button 
          onClick={() => handleSelectRole('family')}
          disabled={loading !== null}
          className="group relative bg-white rounded-[2rem] border-2 border-[#E7DFD4] p-8 text-left hover:border-[#5A6844] hover:shadow-xl transition-all disabled:opacity-50 overflow-hidden"
        >
          <div className="absolute top-0 right-0 w-32 h-32 bg-[#FAF6EE] rounded-bl-full -z-10 group-hover:bg-[#E3ECE1] transition-colors"></div>
          
          <div className="w-16 h-16 bg-[#FAF6EE] rounded-2xl flex items-center justify-center text-[#B0662E] mb-6 group-hover:bg-white group-hover:shadow-sm transition-all border border-[#E7DFD4]/50">
            <Users className="w-8 h-8" />
          </div>
          
          <h2 className="font-serif text-2xl font-bold text-[#2D3325] mb-3">
            I am a Family Member
          </h2>
          <p className="text-[#5C6450] mb-8 min-h-[48px]">
            I am looking for professional, vetted caregivers for a loved one.
          </p>
          
          <div className="flex items-center text-[#5A6844] font-semibold group-hover:translate-x-2 transition-transform">
            {loading === 'family' ? 'Setting up...' : 'Continue as Family'} 
            <ChevronRight className="w-5 h-5 ml-1" />
          </div>
        </button>

        {/* Caregiver Card */}
        <button 
          onClick={() => handleSelectRole('caregiver')}
          disabled={loading !== null}
          className="group relative bg-white rounded-[2rem] border-2 border-[#E7DFD4] p-8 text-left hover:border-[#5A6844] hover:shadow-xl transition-all disabled:opacity-50 overflow-hidden"
        >
          <div className="absolute top-0 right-0 w-32 h-32 bg-[#FAF6EE] rounded-bl-full -z-10 group-hover:bg-[#E3ECE1] transition-colors"></div>
          
          <div className="w-16 h-16 bg-[#FAF6EE] rounded-2xl flex items-center justify-center text-[#5A6844] mb-6 group-hover:bg-white group-hover:shadow-sm transition-all border border-[#E7DFD4]/50">
            <Briefcase className="w-8 h-8" />
          </div>
          
          <h2 className="font-serif text-2xl font-bold text-[#2D3325] mb-3">
            I am a Caregiver
          </h2>
          <p className="text-[#5C6450] mb-8 min-h-[48px]">
            I am a professional caregiver looking to provide care and find shifts.
          </p>
          
          <div className="flex items-center text-[#5A6844] font-semibold group-hover:translate-x-2 transition-transform">
            {loading === 'caregiver' ? 'Setting up...' : 'Continue as Caregiver'} 
            <ChevronRight className="w-5 h-5 ml-1" />
          </div>
        </button>

      </div>
    </div>
  );
}
