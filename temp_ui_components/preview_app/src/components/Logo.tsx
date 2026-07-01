import React from 'react';

interface LogoProps {
  className?: string;
  variant?: 'primary' | 'reversed' | 'solid-field';
}

export default function Logo({ className = "w-10 h-10", variant = 'primary' }: LogoProps) {
  
  if (variant === 'solid-field') {
    return (
      <div className={`bg-[#B0662E] rounded-2xl flex items-center justify-center ${className}`}>
        <svg viewBox="0 0 100 100" className="w-[60%] h-[60%]" role="img" aria-label="Golden Care Logo">
          <path d="M50 30 C42 16, 20 18, 15 36 C10 54, 26 64, 40 76 C36 82, 28 85, 20 83"
                fill="none" stroke="#FAF3E7" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M50 30 C58 16, 80 18, 85 36 C90 54, 74 64, 60 76 C64 82, 72 85, 80 83"
                fill="none" stroke="#FAF3E7" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </div>
    );
  }

  const color = variant === 'reversed' ? '#EAD9B8' : '#B0662E';

  return (
    <svg viewBox="0 0 100 100" className={className} role="img" aria-label="Golden Care Logo">
      <path d="M50 30 C42 16, 20 18, 15 36 C10 54, 26 64, 40 76 C36 82, 28 85, 20 83"
            fill="none" stroke={color} strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M50 30 C58 16, 80 18, 85 36 C90 54, 74 64, 60 76 C64 82, 72 85, 80 83"
            fill="none" stroke={color} strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
