import { ShieldCheck, FileSearch, GraduationCap, HeartPulse } from "lucide-react";

export default function CaregiverVetting() {
  return (
    <section id="vetting" className="py-24 bg-[#2D3325] text-[#FAF6EE]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          
          <div className="space-y-8">
            <div>
              <div className="inline-flex items-center gap-2 px-4 py-2 bg-[#5A6844]/20 rounded-full text-[#E3ECE1] text-sm font-semibold mb-6 border border-[#5A6844]/30">
                <ShieldCheck className="w-4 h-4" />
                <span>Our Safety Promise</span>
              </div>
              <h2 className="font-serif text-4xl lg:text-5xl font-bold mb-6 leading-tight">
                Trust isn't given. <br/>
                <span className="text-[#A4B486]">It's verified.</span>
              </h2>
              <p className="text-lg text-[#C5CEB6] leading-relaxed">
                We understand the immense trust required to invite a caregiver into your home. That's why GoldenCare employs the most rigorous vetting process in India, ensuring your loved ones are in the safest possible hands.
              </p>
            </div>

            <div className="space-y-6">
              <div className="flex gap-4">
                <div className="mt-1 w-10 h-10 rounded-full bg-[#5A6844]/20 flex items-center justify-center shrink-0">
                  <FileSearch className="w-5 h-5 text-[#A4B486]" />
                </div>
                <div>
                  <h4 className="text-lg font-bold mb-1">Rigorous Background Checks</h4>
                  <p className="text-[#C5CEB6] text-sm leading-relaxed">Comprehensive 5-point verification including criminal records, permanent address verification, and strict reference checks from previous employers.</p>
                </div>
              </div>

              <div className="flex gap-4">
                <div className="mt-1 w-10 h-10 rounded-full bg-[#5A6844]/20 flex items-center justify-center shrink-0">
                  <GraduationCap className="w-5 h-5 text-[#A4B486]" />
                </div>
                <div>
                  <h4 className="text-lg font-bold mb-1">Clinical & Empathy Training</h4>
                  <p className="text-[#C5CEB6] text-sm leading-relaxed">Only 4% of applicants pass our assessment. Hires undergo specialized training for geriatric care, dementia support, and compassionate communication.</p>
                </div>
              </div>

              <div className="flex gap-4">
                <div className="mt-1 w-10 h-10 rounded-full bg-[#5A6844]/20 flex items-center justify-center shrink-0">
                  <HeartPulse className="w-5 h-5 text-[#A4B486]" />
                </div>
                <div>
                  <h4 className="text-lg font-bold mb-1">Ongoing Health Monitoring</h4>
                  <p className="text-[#C5CEB6] text-sm leading-relaxed">Our caregivers undergo regular health screenings and are supervised by senior nursing staff who conduct routine unannounced quality-check visits.</p>
                </div>
              </div>
            </div>
          </div>

          <div className="relative">
            <div className="absolute inset-0 bg-gradient-to-tr from-[#5A6844]/40 to-transparent rounded-[3rem] transform translate-x-4 translate-y-4"></div>
            <img 
              src="/images/image2.jpg" 
              alt="Caregiver holding patient's hand" 
              className="relative z-10 w-full h-[600px] object-cover rounded-[3rem] shadow-2xl border border-[#5A6844]/20"
            />
            
            {/* Floating Badge */}
            <div className="absolute bottom-10 -left-10 z-20 bg-white p-6 rounded-3xl shadow-2xl border border-[#E7DFD4] max-w-xs animate-bounce" style={{ animationDuration: '4s' }}>
              <div className="flex items-center gap-4 mb-2">
                <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                  <ShieldCheck className="w-6 h-6 text-green-700" />
                </div>
                <div>
                  <div className="font-bold text-[#2D3325] text-xl">100%</div>
                  <div className="text-xs font-semibold text-[#5C6450] uppercase tracking-wider">Police Verified</div>
                </div>
              </div>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
