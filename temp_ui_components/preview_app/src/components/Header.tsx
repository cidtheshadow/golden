import { useState, useEffect } from "react";
import { Menu, X, Heart, ShieldCheck, Phone, LogOut } from "lucide-react";
import Logo from "./Logo";
import { auth } from "../firebase";
import { onAuthStateChanged, signOut, User } from "firebase/auth";

interface HeaderProps {
  onOpenConsultation: () => void;
  onOpenAdvisorChat: () => void;
  onOpenAuth: () => void;
}

export default function Header({
  onOpenConsultation,
  onOpenAdvisorChat,
  onOpenAuth
}: HeaderProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
    });
    return () => unsubscribe();
  }, []);

  const handleSignOut = () => {
    signOut(auth);
  };

  const navItems = [
    { label: "Services", id: "services" },
    { label: "How It Works", id: "how-it-works" },
    { label: "Trust & Safety", id: "vetting" },
    { label: "FAQ", id: "faq" },
  ];

  const handleNavClick = (id: string) => {
    setMobileMenuOpen(false);
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const handleLogoClick = () => {
    setMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <header id="gc-header" className="sticky top-0 z-40 bg-[#FAF6EE]/95 backdrop-blur-md border-b border-[#E7DFD4]/55 transition-all">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-20">
          
          {/* Logo */}
          <div 
            id="gc-logo" 
            className="flex items-center gap-2.5 cursor-pointer select-none group"
            onClick={handleLogoClick}
          >
            <Logo variant="solid-field" className="w-10 h-10 shadow-sm group-hover:scale-105 transition-transform duration-300" />
            <div>
              <span className="font-serif text-2xl font-bold tracking-tight text-[#2B2620]">
                GoldenCare
              </span>
              <div className="flex items-center gap-1 text-[9px] font-mono text-[#A38A5C] uppercase tracking-widest mt-[-2px]">
                HOME & ELDER CARE
              </div>
            </div>
          </div>

          {/* Desktop Nav Links */}
          <nav id="gc-desktop-nav" className="hidden md:flex items-center gap-8">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => handleNavClick(item.id)}
                className="text-sm font-medium tracking-wide text-[#5C6450] hover:text-[#2D3325] transition-colors relative py-2 cursor-pointer"
              >
                {item.label}
              </button>
            ))}
          </nav>

          {/* Right Action */}
          <div className="hidden md:flex items-center gap-5">
            <div className="flex items-center gap-2 text-[#5A6844] font-semibold text-sm mr-2 border-r border-[#E7DFD4] pr-5">
              <Phone className="w-4 h-4" />
              <span>1800-123-4567</span>
            </div>
            
            {user ? (
              <div className="flex items-center gap-2 bg-[#E3ECE1]/40 px-3 py-1.5 rounded-full border border-[#E3ECE1]">
                <span className="text-sm font-medium text-[#2D3325] max-w-[100px] truncate" title={user.email || ''}>
                  {user.displayName || user.email?.split('@')[0]}
                </span>
                <button
                  onClick={handleSignOut}
                  className="p-1 text-[#5C6450] hover:text-[#2D3325] hover:bg-[#E7DFD4]/50 rounded-full transition-colors cursor-pointer"
                  title="Sign Out"
                >
                  <LogOut className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={onOpenAuth}
                className="text-sm font-medium tracking-wide text-[#5C6450] hover:text-[#2D3325] cursor-pointer"
              >
                Sign In
              </button>
            )}

            <button
              onClick={onOpenConsultation}
              className="bg-[#5A6844] text-[#FAF6EE] text-sm font-bold px-6 py-2.5 rounded-full hover:bg-[#485435] transition-all duration-300 shadow-sm hover:shadow cursor-pointer hover:-translate-y-0.5 active:translate-y-0"
            >
              Free Consultation
            </button>
          </div>

          {/* Mobile Menu Button */}
          <div className="flex md:hidden items-center gap-3">
            <button
              onClick={onOpenConsultation}
              className="p-2 text-[#5C6450] bg-[#6D7A56]/10 rounded-full cursor-pointer"
            >
              <Heart className="w-5 h-5 text-[#6D7A56]" />
            </button>
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="p-2 text-[#2D3325] hover:bg-[#E7DFD4]/20 rounded-lg transition-colors cursor-pointer"
            >
              {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
            </button>
          </div>

        </div>
      </div>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div id="gc-mobile-drawer" className="md:hidden bg-[#F7F4EB] border-b border-[#E7DFD4]/50 animate-fade-in">
          <div className="px-4 pt-2 pb-6 space-y-3">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => handleNavClick(item.id)}
                className="block w-full text-left px-4 py-3 rounded-xl text-base font-medium transition-all text-[#5C6450] hover:bg-[#E7DFD4]/20 hover:text-[#2D3325]"
              >
                {item.label}
              </button>
            ))}
            
            <div className="pt-4 border-t border-[#E7DFD4]/50 flex flex-col gap-3 px-4">
              <div className="flex items-center justify-center gap-2 text-[#5A6844] font-semibold text-sm py-2">
                <Phone className="w-4 h-4" />
                <span>Call us: 1800-123-4567</span>
              </div>
              
              {user ? (
                <button
                  onClick={() => {
                    handleSignOut();
                    setMobileMenuOpen(false);
                  }}
                  className="w-full text-center border border-[#6D7A56]/40 text-[#6D7A56] py-2.5 rounded-full text-sm font-medium bg-[#FAF6EE] flex items-center justify-center gap-2"
                >
                  <LogOut className="w-4 h-4" />
                  Sign Out ({user.displayName || user.email?.split('@')[0]})
                </button>
              ) : (
                <button
                  onClick={() => {
                    setMobileMenuOpen(false);
                    onOpenAuth();
                  }}
                  className="w-full text-center border border-[#6D7A56]/40 text-[#6D7A56] py-2.5 rounded-full text-sm font-medium bg-[#FAF6EE]"
                >
                  Sign In to Family Portal
                </button>
              )}

              <button
                onClick={() => {
                  setMobileMenuOpen(false);
                  onOpenConsultation();
                }}
                className="w-full text-center bg-[#5A6844] text-[#FAF6EE] py-3 rounded-full text-sm font-bold shadow-sm"
              >
                Book a Free Consultation
              </button>
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
