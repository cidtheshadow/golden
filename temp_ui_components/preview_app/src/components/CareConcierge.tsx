/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { HeartHandshake, CheckCircle } from "lucide-react";

interface CareConciergeProps {
  onOpenAdvisorChat: () => void;
}

export default function CareConcierge({ onOpenAdvisorChat }: CareConciergeProps) {
  return (
    <section id="gc-concierge" className="bg-[#FAF6EE] py-16 md:py-24">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid md:grid-cols-12 gap-12 items-center">
          
          {/* Mobile Image First helper, Desktop is Right-aligned */}
          <div className="md:col-span-5 md:order-2 flex justify-center relative">
            <div className="relative w-80 h-80 sm:w-96 sm:h-96 md:w-full md:aspect-square max-w-[400px]">
              
              {/* Decorative behind blob */}
              <div className="absolute inset-0 bg-[#E7DFD4] rounded-full scale-105 -rotate-3" />
              
              {/* Image Container with precise circular clipping */}
              <div className="absolute inset-1.5 bg-[#FAF6EE] rounded-full overflow-hidden shadow-md">
                <img
                  id="concierge-img-advisor"
                  src="https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?auto=format&fit=crop&w=800&q=80"
                  alt="A professional caregiver explaining a senior living document to an elderly lady"
                  referrerPolicy="no-referrer"
                  className="w-full h-full object-cover scale-100 hover:scale-105 transition-transform duration-500"
                />
              </div>

              {/* Floating review count badge */}
              <div className="absolute top-4 -right-2 bg-white/95 backdrop-blur px-4 py-2 rounded-xl shadow border border-[#E7DFD4] text-left">
                <p className="text-[10px] font-mono font-bold text-[#6D7A56] tracking-wider uppercase">Advisor Support</p>
                <p className="text-xs font-semibold text-[#2D3325]">Free & Unlimited</p>
              </div>

            </div>
          </div>

          {/* Left Text & Interactive CTA */}
          <div className="md:col-span-7 md:order-1 text-left flex flex-col justify-center">
            <div className="w-12 h-12 rounded-2xl bg-[#6D7A56]/10 flex items-center justify-center mb-6">
              <HeartHandshake className="w-6 h-6 text-[#6D7A56]" />
            </div>
            
            <h2 className="font-serif text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight text-[#2D3325] leading-tight mb-6">
              Your Dedicated<br />
              <span className="text-[#5A6844]">Care Concierge</span>
            </h2>
            
            <p className="text-base sm:text-lg text-[#5C6450] mb-8 leading-relaxed">
              A personal human advisor to guide you through every step, from search to move-in and beyond. Always here for you, 100% free of charge. We listen to your goals, compile optimal local options, coordinate site tours, and help you navigate budget logistics.
            </p>

            <ul className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
              {[
                "Direct help choosing Care Types",
                "Personalized neighborhood options",
                "Arranging private community tours",
                "Transitioning guidance for families"
              ].map((bullet, idx) => (
                <li key={idx} className="flex items-center gap-2.5 text-sm font-medium text-[#2D3325]">
                  <CheckCircle className="w-4 h-4 text-[#5A6844]" />
                  <span>{bullet}</span>
                </li>
              ))}
            </ul>

            <div>
              <button
                id="btn-meet-advisor"
                onClick={onOpenAdvisorChat}
                className="bg-[#5A6844] text-[#FAF6EE] text-sm font-semibold px-8 py-3.5 rounded-full hover:bg-[#485435] transition-all duration-300 shadow-md hover:shadow-lg hover:-translate-y-0.5 active:translate-y-0 cursor-pointer inline-flex items-center gap-2"
              >
                Meet Your Advisor
              </button>
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
