import { useState, useEffect } from "react";
import Header from "./components/Header";
import Hero from "./components/Hero";
import Stats from "./components/Stats";
import ServicesGrid from "./components/ServicesGrid";
import HowItWorks from "./components/HowItWorks";
import CaregiverVetting from "./components/CaregiverVetting";
import Testimonials from "./components/Testimonials";
import FAQ from "./components/FAQ";
import Footer from "./components/Footer";
import ConsultationModal from "./components/ConsultationModal";
import Auth from "./components/Auth";
import LegalModal from "./components/LegalModal";
import RoleSelection from "./components/RoleSelection";
import FamilyPortal from "./components/FamilyPortal";
import CaregiverPortal from "./components/CaregiverPortal";
import { auth, db } from "./firebase";
import { onAuthStateChanged, User } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";

export default function App() {
  const [showConsultationModal, setShowConsultationModal] = useState(false);
  const [showAuthModal, setShowAuthModal] = useState(false);
  const [authRoleRequested, setAuthRoleRequested] = useState<'family' | 'caregiver'>('family');
  const [legalModalTitle, setLegalModalTitle] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [userRole, setUserRole] = useState<'family' | 'caregiver' | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let unsubscribeDoc: () => void;
    
    const unsubscribeAuth = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      if (currentUser) {
        unsubscribeDoc = onSnapshot(doc(db, 'users', currentUser.uid), (userDoc) => {
          if (userDoc.exists() && userDoc.data().role) {
            setUserRole(userDoc.data().role);
          } else {
            setUserRole(null);
          }
          setLoading(false);
        });
      } else {
        setUserRole(null);
        setLoading(false);
      }
    });
    
    return () => {
      unsubscribeAuth();
      if (unsubscribeDoc) unsubscribeDoc();
    };
  }, []);

  useEffect(() => {
    const handleOpenAuth = (e: any) => {
      setAuthRoleRequested(e.detail || 'family');
      setShowAuthModal(true);
    };
    const handleOpenLegal = (e: any) => setLegalModalTitle(e.detail);
    
    document.addEventListener('open-auth-modal', handleOpenAuth);
    document.addEventListener('open-legal', handleOpenLegal);
    
    return () => {
      document.removeEventListener('open-auth-modal', handleOpenAuth);
      document.removeEventListener('open-legal', handleOpenLegal);
    };
  }, []);

  const handleConsultationSubmit = (data: any) => {
    console.log("Consultation Request:", data);
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#FAF6EE] font-sans antialiased">
      
      <Header
        onOpenConsultation={() => setShowConsultationModal(true)}
        onOpenAdvisorChat={() => setShowConsultationModal(true)} // Reusing consultation for now
        onOpenAuth={() => setShowAuthModal(true)}
      />

      <main className="flex-1">
        {loading ? (
          <div className="h-[60vh] flex items-center justify-center">
            <div className="w-8 h-8 border-4 border-[#E7DFD4] border-t-[#5A6844] rounded-full animate-spin"></div>
          </div>
        ) : user && !userRole ? (
          <RoleSelection />
        ) : userRole === 'family' ? (
          <FamilyPortal />
        ) : userRole === 'caregiver' ? (
          <CaregiverPortal />
        ) : (
          <>
            <Hero onOpenConsultation={() => setShowConsultationModal(true)} />
            <Stats />
            <div id="services">
              <ServicesGrid />
            </div>
            <div id="how-it-works">
              <HowItWorks />
            </div>
            <div id="vetting">
              <CaregiverVetting />
            </div>
            <Testimonials />
            <div id="faq">
              <FAQ />
            </div>
          </>
        )}
      </main>

      <Footer
        onSearchCategory={() => {}}
        setActiveTab={() => {}}
        onOpenAdvisorChat={() => setShowConsultationModal(true)}
      />

      {/* Overlays */}
      {showConsultationModal && (
        <ConsultationModal 
          onClose={() => setShowConsultationModal(false)} 
          onSubmit={handleConsultationSubmit}
        />
      )}

      {showAuthModal && (
        <Auth role={authRoleRequested} onClose={() => setShowAuthModal(false)} />
      )}
      
      {legalModalTitle && (
        <LegalModal 
          title={legalModalTitle} 
          onClose={() => setLegalModalTitle(null)} 
        />
      )}

    </div>
  );
}
