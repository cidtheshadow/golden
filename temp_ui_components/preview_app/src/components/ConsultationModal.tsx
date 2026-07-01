import { useState } from "react";
import { X, Calendar, User, Phone, MapPin } from "lucide-react";
import { db } from "../firebase";
import { collection, addDoc } from "firebase/firestore";

interface ConsultationModalProps {
  onClose: () => void;
  onSubmit: (data: any) => void;
}

export default function ConsultationModal({ onClose, onSubmit }: ConsultationModalProps) {
  const [formData, setFormData] = useState({
    patientName: "",
    contactName: "",
    phone: "",
    email: "",
    city: "",
    serviceNeeded: "Not sure yet"
  });
  
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      await addDoc(collection(db, 'consultations'), {
        ...formData,
        createdAt: new Date().toISOString(),
        status: 'new'
      });
      setSuccess(true);
      onSubmit(formData);
      setTimeout(() => {
        onClose();
      }, 3000);
    } catch (error) {
      console.error("Error adding document: ", error);
      alert("Failed to submit request. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-[#FAF6EE] rounded-[2rem] shadow-2xl border border-[#E7DFD4] w-full max-w-lg overflow-hidden transform animate-scale-up text-left relative max-h-[90vh] overflow-y-auto">
        
        {success ? (
          <div className="p-12 text-center space-y-4">
            <div className="w-20 h-20 bg-[#E3ECE1] rounded-full flex items-center justify-center mx-auto mb-6">
              <Calendar className="w-10 h-10 text-[#5A6844]" />
            </div>
            <h3 className="font-serif text-2xl font-bold text-[#2D3325]">Request Received</h3>
            <p className="text-[#5C6450]">
              Thank you, {formData.contactName}. One of our senior care managers will call you at {formData.phone} within the next 2 hours to discuss your family's needs.
            </p>
          </div>
        ) : (
          <>
            <div className="px-8 py-6 border-b border-[#E7DFD4]/50 flex justify-between items-center bg-white sticky top-0 z-10">
              <div>
                <h3 className="font-serif text-2xl font-bold text-[#2D3325]">Free Consultation</h3>
                <p className="text-sm text-[#5C6450] mt-1">Speak with a care expert today.</p>
              </div>
              <button
                onClick={onClose}
                className="p-2 text-[#5C6450] hover:bg-[#E7DFD4]/50 rounded-full transition-colors cursor-pointer"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-8 space-y-5">
              <div className="grid grid-cols-2 gap-5">
                <div className="space-y-1.5 col-span-2 sm:col-span-1">
                  <label className="text-sm font-semibold text-[#2D3325]">Your Name</label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#8F9884]" />
                    <input 
                      required
                      type="text" 
                      value={formData.contactName}
                      onChange={e => setFormData({...formData, contactName: e.target.value})}
                      className="w-full pl-9 pr-4 py-2.5 bg-white border border-[#E7DFD4] rounded-xl focus:ring-2 focus:ring-[#5A6844] focus:outline-none"
                      placeholder="Jane Doe"
                    />
                  </div>
                </div>
                
                <div className="space-y-1.5 col-span-2 sm:col-span-1">
                  <label className="text-sm font-semibold text-[#2D3325]">Patient Name</label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#8F9884]" />
                    <input 
                      required
                      type="text" 
                      value={formData.patientName}
                      onChange={e => setFormData({...formData, patientName: e.target.value})}
                      className="w-full pl-9 pr-4 py-2.5 bg-white border border-[#E7DFD4] rounded-xl focus:ring-2 focus:ring-[#5A6844] focus:outline-none"
                      placeholder="Parent's Name"
                    />
                  </div>
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-sm font-semibold text-[#2D3325]">Phone Number</label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#8F9884]" />
                  <input 
                    required
                    type="tel" 
                    value={formData.phone}
                    onChange={e => setFormData({...formData, phone: e.target.value})}
                    className="w-full pl-9 pr-4 py-2.5 bg-white border border-[#E7DFD4] rounded-xl focus:ring-2 focus:ring-[#5A6844] focus:outline-none"
                    placeholder="+91 98765 43210"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-5">
                <div className="space-y-1.5 col-span-2 sm:col-span-1">
                  <label className="text-sm font-semibold text-[#2D3325]">City in India</label>
                  <div className="relative">
                    <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[#8F9884]" />
                    <select 
                      required
                      value={formData.city}
                      onChange={e => setFormData({...formData, city: e.target.value})}
                      className="w-full pl-9 pr-4 py-2.5 bg-white border border-[#E7DFD4] rounded-xl focus:ring-2 focus:ring-[#5A6844] focus:outline-none appearance-none"
                    >
                      <option value="">Select a city</option>
                      <option value="Delhi NCR">Delhi NCR</option>
                      <option value="Mumbai">Mumbai</option>
                      <option value="Bangalore">Bangalore</option>
                      <option value="Chennai">Chennai</option>
                      <option value="Hyderabad">Hyderabad</option>
                      <option value="Pune">Pune</option>
                      <option value="Other">Other</option>
                    </select>
                  </div>
                </div>

                <div className="space-y-1.5 col-span-2 sm:col-span-1">
                  <label className="text-sm font-semibold text-[#2D3325]">Primary Care Need</label>
                  <select 
                    value={formData.serviceNeeded}
                    onChange={e => setFormData({...formData, serviceNeeded: e.target.value})}
                    className="w-full px-4 py-2.5 bg-white border border-[#E7DFD4] rounded-xl focus:ring-2 focus:ring-[#5A6844] focus:outline-none appearance-none"
                  >
                    <option value="Not sure yet">Not sure yet</option>
                    <option value="In-home personal care">In-home personal care</option>
                    <option value="Nursing care">Nursing care</option>
                    <option value="Companionship">Companionship</option>
                    <option value="Physiotherapy">Physiotherapy</option>
                    <option value="Post-operative care">Post-operative care</option>
                  </select>
                </div>
              </div>

              <div className="pt-4">
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-[#5A6844] text-[#FAF6EE] font-bold text-lg py-4 rounded-xl hover:bg-[#485435] transition-all cursor-pointer shadow-lg hover:shadow-xl flex items-center justify-center disabled:opacity-80"
                >
                  {loading ? (
                    <div className="w-6 h-6 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  ) : (
                    "Request Call Back"
                  )}
                </button>
                <p className="text-center text-xs text-[#8F9884] mt-3 flex items-center justify-center gap-1">
                  Your information is secure and confidential.
                </p>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  );
}
