import { auth } from "../firebase";
import { Briefcase, Calendar, CheckCircle2, ChevronRight, Clock, MapPin, Wallet } from "lucide-react";

export default function CaregiverPortal() {
  const user = auth.currentUser;

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      
      {/* Header Section */}
      <div className="bg-[#2D3325] rounded-[2rem] border border-[#3E4633] p-8 md:p-12 mb-8 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-[#5A6844] rounded-full blur-3xl opacity-30 -translate-y-1/2 translate-x-1/2 pointer-events-none"></div>
        <div className="relative z-10 flex flex-col md:flex-row md:justify-between md:items-end gap-6">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-[#5A6844]/30 border border-[#5A6844] rounded-full text-[#FAF6EE] text-xs font-bold uppercase tracking-wider mb-4">
              <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse"></span>
              Available for Shifts
            </div>
            <h1 className="font-serif text-4xl md:text-5xl font-bold text-[#FAF6EE] mb-2">
              Hello, <span className="text-[#A38A5C]">{user?.displayName?.split(' ')[0] || 'Caregiver'}</span>
            </h1>
            <p className="text-[#A39B8F] text-lg max-w-xl">
              You have 2 upcoming shifts this week. Ensure your location tracking is active when you clock in.
            </p>
          </div>
          <button className="bg-[#5A6844] text-[#FAF6EE] px-8 py-4 rounded-xl font-bold hover:bg-[#485435] transition-all shadow-sm flex items-center justify-center gap-2 text-lg">
            <Clock className="w-5 h-5" /> Clock In Now
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        {/* Left Column (2/3 width on desktop) */}
        <div className="lg:col-span-2 space-y-8">
          
          {/* Assigned Shifts */}
          <div className="bg-white rounded-[2rem] border border-[#E7DFD4] p-8">
            <div className="flex justify-between items-center mb-6">
              <h3 className="font-bold text-[#2D3325] text-xl">Assigned Shifts</h3>
              <button className="text-[#5A6844] font-semibold text-sm hover:underline flex items-center">Full Schedule <ChevronRight className="w-4 h-4 ml-1" /></button>
            </div>
            
            <div className="space-y-4">
              {/* Mock Shift 1 */}
              <div className="bg-[#FAF6EE] rounded-2xl border border-[#E7DFD4] p-5 relative overflow-hidden">
                <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-[#B0662E]"></div>
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 ml-2">
                  <div>
                    <h4 className="font-bold text-[#2D3325] text-lg">The Sharma Family</h4>
                    <p className="text-[#5C6450] text-sm mt-1">Companionship & Light Housekeeping</p>
                    <div className="flex flex-wrap gap-4 mt-3 text-sm text-[#8F9884]">
                      <span className="flex items-center gap-1.5"><Calendar className="w-4 h-4" /> Today, 9:00 AM - 2:00 PM</span>
                      <span className="flex items-center gap-1.5"><MapPin className="w-4 h-4" /> Sector 15, Chandigarh</span>
                    </div>
                  </div>
                  <button className="px-5 py-2.5 bg-white border border-[#E7DFD4] rounded-lg font-semibold text-[#5A6844] hover:bg-[#E3ECE1]/30 transition-colors whitespace-nowrap">
                    View Details
                  </button>
                </div>
              </div>

              {/* Mock Shift 2 */}
              <div className="bg-white rounded-2xl border border-[#E7DFD4] p-5 relative overflow-hidden opacity-80">
                <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-[#5A6844]"></div>
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 ml-2">
                  <div>
                    <h4 className="font-bold text-[#2D3325] text-lg">Mrs. Kapoor</h4>
                    <p className="text-[#5C6450] text-sm mt-1">Post-Op Care</p>
                    <div className="flex flex-wrap gap-4 mt-3 text-sm text-[#8F9884]">
                      <span className="flex items-center gap-1.5"><Calendar className="w-4 h-4" /> Thu, 10:00 AM - 4:00 PM</span>
                      <span className="flex items-center gap-1.5"><MapPin className="w-4 h-4" /> Mohali Phase 7</span>
                    </div>
                  </div>
                  <button className="px-5 py-2.5 bg-white border border-[#E7DFD4] rounded-lg font-semibold text-[#5C6450] hover:bg-[#FAF6EE] transition-colors whitespace-nowrap">
                    View Details
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Admin Updates */}
          <div className="bg-white rounded-[2rem] border border-[#E7DFD4] p-8">
            <h3 className="font-bold text-[#2D3325] text-xl mb-4">Administration Updates</h3>
            <div className="flex gap-4 p-4 bg-[#E3ECE1]/30 rounded-xl border border-[#E3ECE1]">
              <CheckCircle2 className="w-6 h-6 text-[#5A6844] shrink-0" />
              <div>
                <h4 className="font-bold text-[#2D3325] text-sm">Background Check Renewed</h4>
                <p className="text-[#5C6450] text-sm mt-1">Your annual background check has been cleared. You are fully compliant for the next 12 months.</p>
              </div>
            </div>
          </div>

        </div>

        {/* Right Column (1/3 width on desktop) */}
        <div className="space-y-8">
          
          {/* Earnings */}
          <div className="bg-[#FAF6EE] rounded-[2rem] border border-[#E7DFD4] p-8">
            <div className="flex items-center justify-between mb-6">
              <h3 className="font-bold text-[#2D3325] text-xl">Earnings</h3>
              <Wallet className="w-6 h-6 text-[#5A6844]" />
            </div>
            
            <div className="space-y-6">
              <div>
                <p className="text-[#8F9884] text-sm font-semibold uppercase tracking-wider mb-1">This Week</p>
                <div className="text-4xl font-serif font-bold text-[#2D3325]">₹8,450</div>
                <div className="flex items-center gap-2 mt-2">
                  <span className="text-xs font-bold text-green-600 bg-green-100 px-2 py-0.5 rounded-full">+12%</span>
                  <span className="text-xs text-[#5C6450]">vs last week</span>
                </div>
              </div>

              <div className="h-px bg-[#E7DFD4] w-full"></div>

              <div className="flex justify-between items-center">
                <div>
                  <p className="text-[#8F9884] text-xs font-semibold uppercase tracking-wider mb-1">Total Hours</p>
                  <p className="font-bold text-[#2D3325] text-lg">34.5 hrs</p>
                </div>
                <div className="text-right">
                  <p className="text-[#8F9884] text-xs font-semibold uppercase tracking-wider mb-1">Completion</p>
                  <p className="font-bold text-[#2D3325] text-lg">100%</p>
                </div>
              </div>
            </div>

            <button className="w-full mt-8 py-3 bg-white border border-[#E7DFD4] text-[#2D3325] font-semibold rounded-xl hover:bg-[#E3ECE1]/20 transition-colors shadow-sm">
              View Payslips
            </button>
          </div>

        </div>

      </div>

    </div>
  );
}
