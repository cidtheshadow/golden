/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { Users, ShieldCheck, Building } from "lucide-react";

export default function Stats() {
  const statsList = [
    {
      id: "stat-families",
      icon: <Users className="w-6 h-6 text-[#5A6844]" />,
      num: "10k+",
      label: "Families Trusted"
    },
    {
      id: "stat-vetted",
      icon: <ShieldCheck className="w-6 h-6 text-[#5A6844]" />,
      num: "100%",
      label: "Background Checked"
    },
    {
      id: "stat-partners",
      icon: <Building className="w-6 h-6 text-[#5A6844]" />,
      num: "500+",
      label: "Partner Communities"
    }
  ];

  return (
    <section id="gc-stats" className="bg-[#FAF6EE] py-4">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Soft, beautiful, wavy-looking container in sage green */}
        <div className="bg-[#E3ECE1] rounded-[2.5rem] py-10 px-8 sm:px-12 md:px-16 shadow-[0_4px_24px_rgba(90,104,68,0.03)] border border-[#D1E0CE]/40">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 md:gap-4 items-center">
            {statsList.map((stat, idx) => (
              <div 
                key={stat.id}
                id={stat.id}
                className={`flex flex-col sm:flex-row items-center gap-4 text-center sm:text-left justify-center ${
                  idx !== statsList.length - 1 ? "md:border-r border-[#5A6844]/15" : ""
                }`}
              >
                <div className="w-12 h-12 rounded-full bg-[#FAF6EE] flex items-center justify-center shadow-sm shrink-0">
                  {stat.icon}
                </div>
                <div>
                  <h3 className="font-serif text-3xl sm:text-4xl font-bold text-[#2D3325] tracking-tight">
                    {stat.num}
                  </h3>
                  <p className="text-xs sm:text-sm font-medium text-[#5C6450] tracking-wide mt-1">
                    {stat.label}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
