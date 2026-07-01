import { X } from "lucide-react";

interface LegalModalProps {
  title: string;
  onClose: () => void;
}

export default function LegalModal({ title, onClose }: LegalModalProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-[#FAF6EE] rounded-[2rem] shadow-2xl border border-[#E7DFD4] w-full max-w-2xl overflow-hidden transform animate-scale-up text-left relative max-h-[90vh] flex flex-col">
        
        <div className="px-8 py-6 border-b border-[#E7DFD4]/50 flex justify-between items-center bg-white sticky top-0 z-10 shrink-0">
          <h3 className="font-serif text-2xl font-bold text-[#2D3325]">{title}</h3>
          <button
            onClick={onClose}
            className="p-2 text-[#5C6450] hover:bg-[#E7DFD4]/50 rounded-full transition-colors cursor-pointer"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-8 overflow-y-auto space-y-4 text-[#5C6450] text-sm leading-relaxed">
          {title === 'Privacy Policy' && (
            <>
              <h4 className="font-bold text-[#2D3325] text-base">1. Information We Collect</h4>
              <p>GoldenCare collects personal information such as names, contact details, medical history, and specific care requirements to provide tailored eldercare services. We also collect usage data when you interact with our website to improve user experience.</p>
              
              <h4 className="font-bold text-[#2D3325] text-base mt-6">2. How We Use Your Information</h4>
              <p>Your information is used strictly to pair your family with the most suitable caregivers, process payments, and ensure the safety and wellbeing of the seniors under our care. We may also use your contact information to send important service updates.</p>
              
              <h4 className="font-bold text-[#2D3325] text-base mt-6">3. Data Security and Sharing</h4>
              <p>We implement industry-standard security measures to protect your data. Your information is never sold to third parties. We only share necessary medical and contact details with your assigned, fully vetted caregivers under strict confidentiality agreements.</p>
            </>
          )}

          {title === 'Terms and Conditions' && (
            <>
              <h4 className="font-bold text-[#2D3325] text-base">1. Service Agreement</h4>
              <p>By using GoldenCare services, you agree to provide accurate medical and personal information regarding the senior requiring care. Our caregivers are trained professionals, but GoldenCare is not a substitute for emergency medical services.</p>
              
              <h4 className="font-bold text-[#2D3325] text-base mt-6">2. Caregiver Vetting and Placement</h4>
              <p>GoldenCare conducts rigorous background checks, including police verification and reference checks. However, if you are unsatisfied with a caregiver, you may request a replacement within 48 hours of service commencement.</p>
            </>
          )}

          {title === 'Data Collection' && (
            <>
              <h4 className="font-bold text-[#2D3325] text-base">1. Consent to Collection</h4>
              <p>By submitting forms on our website or registering an account, you consent to the collection and storage of your data in our secure databases (hosted via Firebase). This includes lead generation data and authentication credentials.</p>
              
              <h4 className="font-bold text-[#2D3325] text-base mt-6">2. Right to Deletion</h4>
              <p>You reserve the right to request the complete deletion of your data from our systems at any time by contacting our support team at info@goldencares.in.</p>
            </>
          )}

          {title === 'Refund Policy' && (
            <>
              <h4 className="font-bold text-[#2D3325] text-base">1. Cancellation and Refunds</h4>
              <p>If you cancel a scheduled service at least 24 hours in advance, you are eligible for a full refund. Cancellations made within 24 hours of the scheduled service may be subject to a cancellation fee equivalent to one day of service.</p>
              
              <h4 className="font-bold text-[#2D3325] text-base mt-6">2. Processing Time</h4>
              <p>Approved refunds will be processed and credited back to the original method of payment within 5-7 business days.</p>
            </>
          )}
        </div>

      </div>
    </div>
  );
}
