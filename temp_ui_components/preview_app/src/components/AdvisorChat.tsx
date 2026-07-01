/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useRef } from "react";
import { X, Send, Heart, RefreshCw, AlertCircle, Sparkles } from "lucide-react";
import { Message } from "../types";

interface AdvisorChatProps {
  onClose: () => void;
}

export default function AdvisorChat({ onClose }: AdvisorChatProps) {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: "init-1",
      sender: "advisor",
      text: "Hello! I'm Sarah, your GoldenCare Senior Care Concierge. Finding the right care options for an aging parent or loved one can feel overwhelming, but please know you don't have to navigate it alone.\n\nWhether you are looking into Assisted Living, specialized Memory Care, or Independent Senior Living, I'm here to answer your questions, clarify costs, and help compile optimal options. How can I support your family today?",
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }
  ]);
  const [inputText, setInputText] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto scroll to bottom on message
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isTyping]);

  const starterQuestions = [
    "What is the difference between Assisted and Independent living?",
    "How do I know if Mom needs specialized Memory Care?",
    "What are the typical starting costs for senior living?",
    "How does GoldenCare vet and background check partners?"
  ];

  const handleSendMessage = async (textToSend: string) => {
    if (!textToSend.trim()) return;

    setErrorMsg(null);
    const userMessage: Message = {
      id: "user-" + Math.random().toString(36).substr(2, 9),
      sender: "user",
      text: textToSend,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputText("");
    setIsTyping(true);

    try {
      // Send message history to Express backend
      const response = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: [...messages, userMessage].map(m => ({
            sender: m.sender,
            text: m.text
          }))
        })
      });

      if (!response.ok) {
        throw new Error("Failed to reach advisor service.");
      }

      const data = await response.json();
      
      const advisorMessage: Message = {
        id: "advisor-" + Math.random().toString(36).substr(2, 9),
        sender: "advisor",
        text: data.text,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setMessages((prev) => [...prev, advisorMessage]);
    } catch (error) {
      console.error("Chat error:", error);
      setErrorMsg("I apologize, but I had trouble processing that message. Please try again.");
    } finally {
      setIsTyping(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    handleSendMessage(inputText);
  };

  const handleResetChat = () => {
    setMessages([
      {
        id: "init-1",
        sender: "advisor",
        text: "Hello! I'm Sarah, your GoldenCare Senior Care Advisor. I'm fully refreshed and ready to assist you. What questions or concerns can I help clarify regarding local care programs?",
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }
    ]);
    setErrorMsg(null);
  };

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-xs">
      
      {/* Tap outside container to close */}
      <div className="flex-1" onClick={onClose} />

      {/* Slide-over panel */}
      <div className="w-full max-w-lg bg-[#FAF6EE] h-full flex flex-col shadow-2xl border-l border-[#E7DFD4]/80 animate-slide-left">
        
        {/* Chat Drawer Header */}
        <div className="px-6 py-5 border-b border-[#E7DFD4]/50 flex justify-between items-center bg-[#E3ECE1]/30">
          <div className="flex items-center gap-3 text-left">
            <div className="w-12 h-12 rounded-full bg-[#6D7A56] flex items-center justify-center text-[#FAF6EE] relative shadow-sm">
              <Heart className="w-5 h-5 fill-[#FAF6EE]/15" />
              <span className="absolute bottom-0 right-0 w-3.5 h-3.5 bg-emerald-500 border-2 border-[#FAF6EE] rounded-full" />
            </div>
            <div>
              <h3 className="font-serif text-lg font-bold text-[#2D3325] flex items-center gap-1.5">
                Sarah <span className="text-[10px] font-mono font-medium text-[#FAF6EE] bg-[#6D7A56] px-1.5 py-0.5 rounded-full uppercase tracking-wider">AI Advisor</span>
              </h3>
              <p className="text-xs text-[#5C6450]">GoldenCare Concierge • Active Now</p>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <button
              onClick={handleResetChat}
              title="Reset conversation history"
              className="p-2 text-[#5C6450] hover:bg-[#E7DFD4]/50 rounded-full transition-colors cursor-pointer"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
            <button
              onClick={onClose}
              className="p-2 text-[#5C6450] hover:bg-[#E7DFD4]/50 rounded-full transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Scrollable Conversation Container */}
        <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5 bg-[#FAF6EE]">
          
          {/* Welcome Tip Box */}
          <div className="bg-[#E3ECE1]/35 rounded-2xl p-4 border border-[#D1E0CE]/30 text-left space-y-2.5">
            <div className="flex items-center gap-2 text-sm font-semibold text-[#2D3325]">
              <Sparkles className="w-4 h-4 text-[#5A6844]" />
              <span>Complimentary Care Advisory</span>
            </div>
            <p className="text-xs text-[#5C6450] leading-relaxed">
              Every query is handled with complete compassion. We compile local options, explain average Medicare or private-pay structures, and help prepare custom checklist worksheets.
            </p>
          </div>

          {/* Render Messages */}
          {messages.map((msg) => (
            <div
              key={msg.id}
              className={`flex flex-col max-w-[85%] text-left ${
                msg.sender === "user" ? "ml-auto items-end" : "mr-auto items-start"
              }`}
            >
              <span className="text-[9px] font-mono text-[#8F9884] mb-1 px-1">
                {msg.sender === "user" ? "You" : "Sarah"} • {msg.timestamp}
              </span>
              <div
                className={`px-4.5 py-3 rounded-2xl text-xs sm:text-sm leading-relaxed whitespace-pre-wrap ${
                  msg.sender === "user"
                    ? "bg-[#5A6844] text-[#FAF6EE] rounded-tr-none shadow-xs"
                    : "bg-white text-[#2D3325] border border-[#E7DFD4]/80 rounded-tl-none shadow-xs"
                }`}
              >
                {msg.text}
              </div>
            </div>
          ))}

          {/* Typing Indicator */}
          {isTyping && (
            <div className="flex flex-col items-start max-w-[85%] text-left mr-auto">
              <span className="text-[9px] font-mono text-[#8F9884] mb-1 px-1">Sarah is formulating guidance...</span>
              <div className="bg-white border border-[#E7DFD4]/80 px-5 py-3 rounded-2xl rounded-tl-none flex items-center gap-1 shadow-xs">
                <span className="w-2 h-2 bg-[#8F9884] rounded-full animate-bounce delay-100" />
                <span className="w-2 h-2 bg-[#8F9884] rounded-full animate-bounce delay-200" />
                <span className="w-2 h-2 bg-[#8F9884] rounded-full animate-bounce delay-300" />
              </div>
            </div>
          )}

          {/* Error Message */}
          {errorMsg && (
            <div className="bg-red-50 text-red-800 text-xs p-3.5 rounded-xl border border-red-200 flex items-start gap-2 max-w-[90%] mx-auto text-left">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{errorMsg}</span>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Starter suggestion buttons (Render only if minimal back and forth) */}
        {messages.length === 1 && !isTyping && (
          <div className="px-6 py-3 border-t border-[#E7DFD4]/40 bg-[#FAF6EE] space-y-2 text-left">
            <span className="text-[10px] font-mono font-bold text-[#8F9884] uppercase tracking-wider">Suggested Questions:</span>
            <div className="flex flex-wrap gap-1.5">
              {starterQuestions.map((q, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSendMessage(q)}
                  className="text-[11px] font-medium text-[#5C6450] bg-white border border-[#E7DFD4] hover:bg-[#6D7A56]/5 px-3 py-1.5 rounded-full transition-all cursor-pointer text-left"
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Chat input box */}
        <form onSubmit={handleSubmit} className="p-4 border-t border-[#E7DFD4]/50 bg-white flex items-center gap-2">
          <input
            id="advisor-message-input"
            type="text"
            required
            disabled={isTyping}
            placeholder="Type your question for Sarah..."
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            className="flex-1 bg-[#FAF6EE] border border-[#E7DFD4] rounded-xl px-4 py-3 text-xs sm:text-sm text-[#2D3325] focus:outline-none focus:border-[#6D7A56]"
          />
          <button
            id="btn-advisor-send"
            type="submit"
            disabled={!inputText.trim() || isTyping}
            className="w-11 h-11 bg-[#5A6844] hover:bg-[#485435] disabled:bg-[#8F9884]/45 disabled:cursor-not-allowed text-white rounded-xl flex items-center justify-center transition-colors cursor-pointer shrink-0"
          >
            <Send className="w-4 h-4" />
          </button>
        </form>

      </div>
    </div>
  );
}
