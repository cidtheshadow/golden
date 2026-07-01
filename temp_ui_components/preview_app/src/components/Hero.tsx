import { ShieldCheck, PhoneCall } from "lucide-react";

interface HeroProps {
  onOpenConsultation: () => void;
}

export default function Hero({ onOpenConsultation }: HeroProps) {
  return (
    <section className="relative bg-[#FAF6EE] pt-12 pb-24 lg:pt-20 lg:pb-32 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-8 items-center">
          
          {/* Text Content */}
          <div className="max-w-2xl">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-[#E3ECE1] rounded-full text-[#5A6844] text-sm font-semibold mb-6 border border-[#5A6844]/20 animate-fade-in">
              <ShieldCheck className="w-4 h-4" />
              <span>India's Most Trusted Care Network</span>
            </div>
            
            <h1 className="font-serif text-5xl lg:text-6xl font-bold text-[#2D3325] leading-[1.1] mb-6 animate-slide-up">
              Compassionate elder care, <br className="hidden md:block"/>
              <span className="text-[#6D7A56]">right at home.</span>
            </h1>
            
            <p className="text-lg lg:text-xl text-[#5C6450] mb-8 leading-relaxed max-w-xl animate-slide-up" style={{ animationDelay: '0.1s' }}>
              We provide vetted, trained caregivers and nursing support so your aging parents can live safely and with dignity in the comfort of their own home.
            </p>
            
            <div className="flex flex-col sm:flex-row gap-4 animate-slide-up" style={{ animationDelay: '0.2s' }}>
              <button
                onClick={onOpenConsultation}
                className="bg-[#5A6844] text-[#FAF6EE] font-bold text-lg px-8 py-4 rounded-full hover:bg-[#485435] transition-all cursor-pointer shadow-lg hover:shadow-xl flex items-center justify-center gap-2 hover:-translate-y-1"
              >
                Book a free consultation
              </button>
              <a 
                href="tel:18001234567"
                className="bg-white text-[#2D3325] font-semibold text-lg px-8 py-4 rounded-full border border-[#E7DFD4] hover:bg-[#F7F4EB] transition-all cursor-pointer flex items-center justify-center gap-2"
              >
                <PhoneCall className="w-5 h-5 text-[#5A6844]" />
                1800-123-4567
              </a>
            </div>

            <div className="mt-8 flex items-center gap-6 text-sm font-medium text-[#8F9884]">
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#6D7A56]" />
                100% Police Verified
              </div>
              <div className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#6D7A56]" />
                Nurse Supervised
              </div>
            </div>
          </div>

          {/* Image Content */}
          <div className="relative animate-fade-in" style={{ animationDelay: '0.3s' }}>
            <div className="absolute inset-0 bg-[#E3ECE1] rounded-[3rem] transform translate-x-4 translate-y-4"></div>
            <img 
              src="/images/image1.jpg" 
              alt="Elderly Indian man smiling with a caregiver" 
              className="relative z-10 w-full h-[500px] object-cover rounded-[3rem] shadow-2xl"
            />
          </div>

        </div>
      </div>
    </section>
  );
}
