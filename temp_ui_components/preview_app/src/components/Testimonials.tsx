import { Star, Quote } from "lucide-react";

const testimonials = [
  {
    id: 1,
    name: "Priya Sharma",
    location: "Mumbai",
    content: "Living in the US while my mother was in Mumbai was incredibly stressful. GoldenCare changed everything. The caregiver they sent is like family now, and the daily app updates give me complete peace of mind.",
    rating: 5,
    role: "Daughter of patient"
  },
  {
    id: 2,
    name: "Rahul Verma",
    location: "Delhi NCR",
    content: "After my father's hip surgery, we needed professional post-operative care at home. The nursing staff from GoldenCare was punctual, highly trained, and so compassionate. Highly recommended.",
    rating: 5,
    role: "Son of patient"
  },
  {
    id: 3,
    name: "Anjali Desai",
    location: "Bangalore",
    content: "We hired a companion for my grandfather to help him with daily walks and doctor visits. The vetting process GoldenCare uses is very thorough, which made us feel safe instantly.",
    rating: 5,
    role: "Granddaughter of patient"
  }
];

export default function Testimonials() {
  return (
    <section className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="text-center max-w-2xl mx-auto mb-16">
          <h2 className="font-serif text-4xl font-bold text-[#2D3325] mb-4">
            Families Trust GoldenCare
          </h2>
          <p className="text-[#5C6450]">
            Hear from families across India who have entrusted us with their loved ones' care.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {testimonials.map((testimonial) => (
            <div 
              key={testimonial.id}
              className="bg-[#FAF6EE] rounded-3xl p-8 relative border border-[#E7DFD4]"
            >
              <Quote className="absolute top-8 right-8 w-8 h-8 text-[#5A6844]/20" />
              
              <div className="flex gap-1 mb-6">
                {[...Array(testimonial.rating)].map((_, i) => (
                  <Star key={i} className="w-5 h-5 fill-[#6D7A56] text-[#6D7A56]" />
                ))}
              </div>
              
              <p className="text-[#2D3325] text-base leading-relaxed mb-8 italic">
                "{testimonial.content}"
              </p>
              
              <div>
                <h4 className="font-bold text-[#2D3325]">{testimonial.name}</h4>
                <p className="text-sm text-[#5C6450]">
                  {testimonial.role} • {testimonial.location}
                </p>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
