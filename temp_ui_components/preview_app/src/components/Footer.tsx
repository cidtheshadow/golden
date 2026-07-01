import { Heart, Mail, MapPin, Users, Briefcase } from "lucide-react";
import Logo from "./Logo";

interface FooterProps {
  onSearchCategory: (category: string) => void;
  setActiveTab: (tab: string) => void;
  onOpenAdvisorChat: () => void;
}

export default function Footer({ onOpenAdvisorChat }: FooterProps) {
  return (
    <footer className="bg-[#2D3325] text-[#FAF6EE] pt-16 pb-8 border-t border-[#3E4633]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12 lg:gap-8 mb-16">
          
          {/* Brand Info */}
          <div className="space-y-6">
            <div className="flex items-center gap-2.5">
              <Logo variant="solid-field" className="w-10 h-10 shadow-sm" />
              <span className="font-serif text-2xl font-bold tracking-tight text-[#FAF6EE]">
                GoldenCare
              </span>
            </div>
            <p className="text-sm text-[#D5CEC4] leading-relaxed max-w-xs">
              Providing compassionate, professional care for seniors in Chandigarh, Punjab.
            </p>
            <div className="space-y-3">
              <a href="mailto:info@goldencares.in" className="flex items-center gap-3 text-sm text-[#D5CEC4] hover:text-[#FAF6EE] transition-colors group">
                <Mail className="w-4 h-4 text-[#A39B8F] group-hover:text-[#FAF6EE] transition-colors" />
                info@goldencares.in
              </a>
              <div className="flex items-center gap-3 text-sm text-[#D5CEC4]">
                <MapPin className="w-4 h-4 text-[#A39B8F]" />
                Chandigarh, Punjab
              </div>
            </div>
          </div>

          {/* Services */}
          <div>
            <h4 className="font-bold text-sm tracking-wider uppercase mb-6 text-[#FAF6EE]">Services</h4>
            <ul className="space-y-4">
              {['Companionship', 'Outings & Visits', 'Daily Activities', 'Exercise & Walks'].map((link) => (
                <li key={link}>
                  <button 
                    onClick={() => {
                      const el = document.getElementById('services');
                      if (el) el.scrollIntoView({ behavior: 'smooth' });
                    }}
                    className="text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer"
                  >
                    {link}
                  </button>
                </li>
              ))}
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="font-bold text-sm tracking-wider uppercase mb-6 text-[#FAF6EE]">Company</h4>
            <ul className="space-y-4">
              <li>
                <button 
                  onClick={() => {
                    const el = document.getElementById('how-it-works');
                    if (el) el.scrollIntoView({ behavior: 'smooth' });
                  }}
                  className="text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer"
                >
                  About Us
                </button>
              </li>
              <li>
                <button 
                  onClick={() => {
                    const el = document.getElementById('vetting');
                    if (el) el.scrollIntoView({ behavior: 'smooth' });
                  }}
                  className="text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer"
                >
                  Our Caregivers
                </button>
              </li>
              <li>
                <button 
                  onClick={onOpenAdvisorChat}
                  className="text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer"
                >
                  Contact
                </button>
              </li>
            </ul>
          </div>

          {/* Portals */}
          <div>
            <h4 className="font-bold text-sm tracking-wider uppercase mb-6 text-[#FAF6EE]">Portals</h4>
            <ul className="space-y-4">
              <li>
                <button onClick={() => {
                  document.dispatchEvent(new CustomEvent('open-auth-modal', { detail: 'family' }));
                }} className="flex items-center gap-3 text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer group">
                  <Users className="w-4 h-4 text-[#A39B8F] group-hover:text-[#FAF6EE] transition-colors" />
                  Family Login
                </button>
              </li>
              <li>
                <button onClick={() => {
                  document.dispatchEvent(new CustomEvent('open-auth-modal', { detail: 'caregiver' }));
                }} className="flex items-center gap-3 text-[#D5CEC4] hover:text-[#FAF6EE] text-sm transition-colors cursor-pointer group">
                  <Briefcase className="w-4 h-4 text-[#A39B8F] group-hover:text-[#FAF6EE] transition-colors" />
                  Caregiver Login
                </button>
              </li>
            </ul>
          </div>

        </div>

        {/* Bottom Bar */}
        <div className="pt-8 border-t border-[#4C453A] flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-sm text-[#A39B8F]">
            © {new Date().getFullYear()} GoldenCare. All rights reserved.
          </p>
          <div className="flex flex-wrap justify-center gap-6 text-sm text-[#A39B8F]">
            <button onClick={() => document.dispatchEvent(new CustomEvent('open-legal', { detail: 'Privacy Policy' }))} className="hover:text-[#FAF6EE] transition-colors">Privacy Policy</button>
            <button onClick={() => document.dispatchEvent(new CustomEvent('open-legal', { detail: 'Terms and Conditions' }))} className="hover:text-[#FAF6EE] transition-colors">Terms and Conditions</button>
            <button onClick={() => document.dispatchEvent(new CustomEvent('open-legal', { detail: 'Data Collection' }))} className="hover:text-[#FAF6EE] transition-colors">Data Collection</button>
            <button onClick={() => document.dispatchEvent(new CustomEvent('open-legal', { detail: 'Refund Policy' }))} className="hover:text-[#FAF6EE] transition-colors">Refund Policy</button>
          </div>
        </div>

      </div>
    </footer>
  );
}
