import { useState } from "react";
import { Plus, Minus } from "lucide-react";

const faqs = [
  {
    question: "How do you ensure the safety and background of your caregivers?",
    answer: "Safety is our top priority. Every GoldenCare caregiver undergoes a rigorous 5-point background check, including police verification, permanent address confirmation, and reference checks from past employers. We only hire the top 4% of applicants."
  },
  {
    question: "What if the caregiver isn't a good match for my parent?",
    answer: "We strive for a perfect match based on medical needs, language, and personality. However, if you or your parent feel the fit isn't right, we will provide a replacement caregiver within 24 hours, no questions asked."
  },
  {
    question: "Can I monitor the care my parent is receiving?",
    answer: "Yes! We provide a family app where caregivers log daily updates, medication administration, and vitals. You also have a dedicated Care Manager you can reach out to at any time for detailed updates."
  },
  {
    question: "What areas in India do you currently serve?",
    answer: "We currently provide in-home care services across major metro cities including Delhi NCR, Mumbai, Bangalore, Chennai, Hyderabad, and Pune. We are rapidly expanding, so please contact us if your city is not listed."
  },
  {
    question: "Is there a long-term contract or minimum commitment?",
    answer: "No. We believe you should stay with us because you love our service, not because of a contract. We offer flexible plans ranging from daily visits to 24/7 live-in care, and you can cancel or pause services with a short notice period."
  }
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="py-24 bg-[#FAF6EE]">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="text-center mb-16">
          <h2 className="font-serif text-4xl font-bold text-[#2D3325] mb-4">
            Frequently Asked Questions
          </h2>
          <p className="text-[#5C6450]">
            Everything you need to know about our care services, safety protocols, and pricing.
          </p>
        </div>

        <div className="space-y-4">
          {faqs.map((faq, index) => (
            <div 
              key={index} 
              className={`bg-white rounded-2xl border transition-all duration-300 overflow-hidden ${
                openIndex === index ? 'border-[#6D7A56] shadow-md' : 'border-[#E7DFD4] hover:border-[#6D7A56]/50'
              }`}
            >
              <button
                onClick={() => setOpenIndex(openIndex === index ? null : index)}
                className="w-full flex items-center justify-between p-6 text-left cursor-pointer focus:outline-none"
              >
                <span className={`font-bold text-lg pr-8 ${openIndex === index ? 'text-[#2D3325]' : 'text-[#5C6450]'}`}>
                  {faq.question}
                </span>
                <span className="shrink-0 bg-[#FAF6EE] p-2 rounded-full">
                  {openIndex === index ? (
                    <Minus className="w-5 h-5 text-[#6D7A56]" />
                  ) : (
                    <Plus className="w-5 h-5 text-[#6D7A56]" />
                  )}
                </span>
              </button>
              
              <div 
                className={`px-6 transition-all duration-300 ease-in-out ${
                  openIndex === index ? 'max-h-96 pb-6 opacity-100' : 'max-h-0 opacity-0'
                }`}
              >
                <p className="text-[#5C6450] leading-relaxed">
                  {faq.answer}
                </p>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
