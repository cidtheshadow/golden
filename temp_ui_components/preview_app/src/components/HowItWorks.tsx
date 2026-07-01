import { ClipboardList, ClipboardCheck, Users, HeartHandshake } from "lucide-react";

const steps = [
  {
    number: "01",
    title: "Free Consultation",
    description: "We start with an in-depth conversation to understand your parent's health needs, personality, and your family's specific requirements.",
    icon: <ClipboardList className="w-6 h-6 text-[#5A6844]" />
  },
  {
    number: "02",
    title: "Customized Care Plan",
    description: "Our medical directors design a tailored, flexible care plan that addresses both immediate medical needs and long-term well-being.",
    icon: <ClipboardCheck className="w-6 h-6 text-[#5A6844]" />
  },
  {
    number: "03",
    title: "Caregiver Match",
    description: "We carefully select a fully-vetted caregiver from our team whose skills, language, and personality best match your family.",
    icon: <Users className="w-6 h-6 text-[#5A6844]" />
  },
  {
    number: "04",
    title: "Ongoing Support",
    description: "Care is dynamic. We provide regular check-ins, app-based updates, and continuous training to ensure care evolves with your needs.",
    icon: <HeartHandshake className="w-6 h-6 text-[#5A6844]" />
  }
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 bg-white relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="text-sm font-bold tracking-widest uppercase text-[#6D7A56] mb-3 block">
            The GoldenCare Process
          </span>
          <h2 className="font-serif text-4xl font-bold text-[#2D3325] mb-6">
            Simple, Transparent, and Stress-Free
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {steps.map((step, index) => (
            <div key={index} className="relative">
              {/* Connector Line for Desktop */}
              {index < steps.length - 1 && (
                <div className="hidden lg:block absolute top-12 left-[60%] w-full h-[2px] bg-gradient-to-r from-[#5A6844]/30 to-transparent z-0" />
              )}
              
              <div className="bg-[#FAF6EE] rounded-3xl p-8 h-full border border-[#E7DFD4] relative z-10 hover:-translate-y-2 transition-transform duration-300">
                <div className="flex justify-between items-start mb-6">
                  <div className="w-12 h-12 bg-white rounded-xl shadow-sm flex items-center justify-center">
                    {step.icon}
                  </div>
                  <span className="font-serif text-3xl font-bold text-[#2D3325]/10">
                    {step.number}
                  </span>
                </div>
                <h3 className="text-lg font-bold text-[#2D3325] mb-3">
                  {step.title}
                </h3>
                <p className="text-[#5C6450] text-sm leading-relaxed">
                  {step.description}
                </p>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
