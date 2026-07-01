import { HeartPulse, Stethoscope, Users, Activity, Crosshair, Sun, ShieldPlus } from "lucide-react";
import { Service } from "../types";

const services: Service[] = [
  {
    id: "svc-1",
    title: "In-home personal care",
    description: "Compassionate assistance with bathing, dressing, mobility, and daily living activities to ensure dignity and comfort.",
    icon: <HeartPulse className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-2",
    title: "Nursing / skilled medical care",
    description: "Certified nurses available for medication management, wound care, IV therapy, and vital sign monitoring.",
    icon: <Stethoscope className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-3",
    title: "Companionship and social engagement",
    description: "Meaningful interaction, conversation, and emotional support to prevent isolation and keep the mind active.",
    icon: <Users className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-4",
    title: "Physiotherapy / rehabilitation support",
    description: "In-home physical therapy to improve strength, balance, and mobility, aiding recovery from surgery or injury.",
    icon: <Activity className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-5",
    title: "Medical escort",
    description: "Safe, accompanied transportation to and from medical appointments, ensuring doctors' instructions are clearly understood.",
    icon: <Crosshair className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-6",
    title: "Adult day care",
    description: "Structured, engaging daytime programs designed to provide social interaction for seniors while families are at work.",
    icon: <Sun className="w-8 h-8 text-[#5A6844]" />,
  },
  {
    id: "svc-7",
    title: "Post-operative care",
    description: "Comprehensive transitional care to support recovery after a hospital stay and reduce the risk of readmission.",
    icon: <ShieldPlus className="w-8 h-8 text-[#5A6844]" />,
  },
];

export default function ServicesGrid() {
  return (
    <section id="services" className="py-24 bg-[#FAF6EE]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h2 className="font-serif text-4xl font-bold text-[#2D3325] mb-6">
            Comprehensive Care in the Comfort of Home
          </h2>
          <p className="text-lg text-[#5C6450] leading-relaxed">
            We provide a full spectrum of specialized elder care services tailored to your family's unique needs, delivered by highly trained and vetted professionals.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
          {services.map((service) => (
            <div 
              key={service.id} 
              className="bg-white rounded-[2rem] p-8 shadow-sm border border-[#E7DFD4] hover:shadow-md transition-all duration-300 group"
            >
              <div className="w-16 h-16 bg-[#E3ECE1]/50 rounded-2xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300">
                {service.icon}
              </div>
              <h3 className="font-serif text-xl font-bold text-[#2D3325] mb-4 leading-tight">
                {service.title}
              </h3>
              <p className="text-[#5C6450] leading-relaxed text-sm">
                {service.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
