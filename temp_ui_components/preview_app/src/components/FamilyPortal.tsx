import { auth } from "../firebase";
import { Calendar, Clock, CreditCard, FileText, MessageCircle, Phone, Star, UserCircle2 } from "lucide-react";

export default function FamilyPortal() {
  const user = auth.currentUser;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      
      {/* Header Section */}
      <div className="bg-[#FAF6EE] rounded-[2rem] border border-[#E7DFD4] p-8 md:p-12 mb-8 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-[#E3ECE1] rounded-full blur-3xl opacity-50 -translate-y-1/2 translate-x-1/2 pointer-events-none"></div>
        <div className="relative z-10">
          <h1 className="font-serif text-4xl md:text-5xl font-bold text-[#2D3325] mb-4">
            Welcome back, <span className="text-[#B0662E]">{user?.displayName?.split(' ')[0] || 'Family'}</span>
          </h1>
          <p className="text-[#5C6450] text-lg max-w-2xl">
            Here's an overview of your active care plans and upcoming visits. Everything you need to manage your family's care in one place.
          </p>
          <div className="mt-8 flex flex-wrap gap-4">
            <button className="bg-[#5A6844] text-[#FAF6EE] px-6 py-3 rounded-xl font-semibold hover:bg-[#485435] transition-all shadow-sm">
              Book Additional Care
            </button>
            <button className="bg-white text-[#2D3325] border border-[#E7DFD4] px-6 py-3 rounded-xl font-semibold hover:bg-[#FAF6EE] transition-all shadow-sm">
              View Full Care Plan
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        {/* Left Column (2/3 width on desktop) */}
        <div className="lg:col-span-2 space-y-8">
          
          {/* Upcoming Schedule */}
          <div className="bg-white rounded-[2rem] border border-[#E7DFD4] p-8">
            <div className="flex justify-between items-center mb-6">
              <h3 className="font-bold text-[#2D3325] text-xl">Upcoming Schedule</h3>
              <button className="text-[#5A6844] font-semibold text-sm hover:underline">View Calendar</button>
            </div>
            
            <div className="space-y-4">
              {/* Mock Visit 1 */}
              <div className="flex gap-4 items-start p-4 bg-[#FAF6EE] rounded-2xl border border-[#E7DFD4]/50 hover:border-[#E7DFD4] transition-colors">
                <div className="bg-white p-3 rounded-xl border border-[#E7DFD4] text-center min-w-[72px]">
                  <div className="text-xs font-bold text-[#8F9884] uppercase">Tomorrow</div>
                  <div className="text-xl font-black text-[#B0662E]">24</div>
                </div>
                <div className="flex-1 pt-1">
                  <h4 className="font-bold text-[#2D3325] text-lg">Companionship & Meal Prep</h4>
                  <div className="flex items-center gap-4 mt-2 text-[#5C6450] text-sm">
                    <span className="flex items-center gap-1.5"><Clock className="w-4 h-4" /> 9:00 AM - 1:00 PM</span>
                    <span className="flex items-center gap-1.5"><UserCircle2 className="w-4 h-4" /> Sarah Jenkins</span>
                  </div>
                </div>
              </div>

              {/* Mock Visit 2 */}
              <div className="flex gap-4 items-start p-4 bg-white rounded-2xl border border-[#E7DFD4]/50 opacity-70">
                <div className="bg-[#FAF6EE] p-3 rounded-xl border border-[#E7DFD4]/50 text-center min-w-[72px]">
                  <div className="text-xs font-bold text-[#8F9884] uppercase">Wed</div>
                  <div className="text-xl font-black text-[#5C6450]">26</div>
                </div>
                <div className="flex-1 pt-1">
                  <h4 className="font-bold text-[#2D3325] text-lg">Physical Therapy Assist</h4>
                  <div className="flex items-center gap-4 mt-2 text-[#5C6450] text-sm">
                    <span className="flex items-center gap-1.5"><Clock className="w-4 h-4" /> 2:00 PM - 5:00 PM</span>
                    <span className="flex items-center gap-1.5"><UserCircle2 className="w-4 h-4" /> Michael Chen</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column (1/3 width on desktop) */}
        <div className="space-y-8">
          
          {/* Assigned Care Team */}
          <div className="bg-white rounded-[2rem] border border-[#E7DFD4] p-8">
            <h3 className="font-bold text-[#2D3325] text-xl mb-6">Your Care Team</h3>
            
            <div className="space-y-6">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-[#E3ECE1] flex items-center justify-center text-[#5A6844] font-bold text-lg">
                  SJ
                </div>
                <div className="flex-1">
                  <h4 className="font-bold text-[#2D3325]">Sarah Jenkins</h4>
                  <p className="text-xs text-[#5C6450]">Primary Caregiver • 4.9 <Star className="w-3 h-3 inline text-[#B0662E] fill-current" /></p>
                </div>
                <button className="p-2 bg-[#FAF6EE] rounded-full text-[#B0662E] hover:bg-[#F0E6D8] transition-colors">
                  <MessageCircle className="w-5 h-5" />
                </button>
              </div>

              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-[#F0E6D8] flex items-center justify-center text-[#B0662E] font-bold text-lg">
                  MC
                </div>
                <div className="flex-1">
                  <h4 className="font-bold text-[#2D3325]">Michael Chen</h4>
                  <p className="text-xs text-[#5C6450]">Specialist • 5.0 <Star className="w-3 h-3 inline text-[#B0662E] fill-current" /></p>
                </div>
                <button className="p-2 bg-[#FAF6EE] rounded-full text-[#B0662E] hover:bg-[#F0E6D8] transition-colors">
                  <MessageCircle className="w-5 h-5" />
                </button>
              </div>
            </div>

            <button className="w-full mt-6 py-3 border border-[#E7DFD4] text-[#5A6844] font-semibold rounded-xl hover:bg-[#FAF6EE] transition-colors">
              Contact Care Coordinator
            </button>
          </div>

          {/* Quick Actions */}
          <div className="bg-[#2D3325] rounded-[2rem] p-8 text-[#FAF6EE]">
            <h3 className="font-bold text-xl mb-6">Billing & Invoices</h3>
            <div className="flex items-end gap-2 mb-6">
              <span className="text-4xl font-serif font-bold">₹14,500</span>
              <span className="text-[#A39B8F] text-sm mb-1">Due Jun 30</span>
            </div>
            <div className="space-y-3">
              <button className="w-full py-3 bg-[#5A6844] hover:bg-[#485435] text-white rounded-xl font-semibold transition-colors flex items-center justify-center gap-2">
                <CreditCard className="w-4 h-4" /> Make Payment
              </button>
              <button className="w-full py-3 border border-[#4C453A] hover:bg-[#3D352A] rounded-xl font-semibold transition-colors flex items-center justify-center gap-2">
                <FileText className="w-4 h-4" /> Download Statement
              </button>
            </div>
          </div>

        </div>

      </div>

    </div>
  );
}
