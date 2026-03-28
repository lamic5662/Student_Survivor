import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { message, mode } = await req.json();
    if (!message || typeof message !== "string") {
      return new Response(
        JSON.stringify({ error: "Message is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const provider = (Deno.env.get("AI_PROVIDER") ?? "openai").toLowerCase();
    const systemPrompt = buildSystemPrompt(mode);
    let reply = "";

    if (provider === "ollama") {
      const baseUrl = Deno.env.get("OLLAMA_BASE_URL") ?? "http://localhost:11434";
      const model = Deno.env.get("OLLAMA_MODEL") ?? "llama3";

      const response = await fetch(`${baseUrl}/api/chat`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          stream: false,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: message },
          ],
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        return new Response(
          JSON.stringify({ error: errorText }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const data = await response.json();
      reply = data?.message?.content?.toString()?.trim() ?? "";
    } else {
      const apiKey = Deno.env.get("OPENAI_API_KEY");
      if (!apiKey) {
        return new Response(
          JSON.stringify({ error: "OPENAI_API_KEY not set" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
      const baseUrl = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";

      const response = await fetch(`${baseUrl}/chat/completions`, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: message },
          ],
          temperature: 0.3,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        return new Response(
          JSON.stringify({ error: errorText }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const data = await response.json();
      reply = data?.choices?.[0]?.message?.content?.toString()?.trim() ?? "";
    }

    return new Response(
      JSON.stringify({ reply }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `${error}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

function buildSystemPrompt(mode?: string) {
  const base =
    "You are a concise study assistant for BCA TU students. Answer clearly, " +
    "using headings or bullet points when helpful.";
  if (!mode) return base;
  const normalized = mode.toLowerCase();
  if (normalized.includes("short")) {
    return `${base} Provide a short 5-mark style answer.`;
  }
  if (normalized.includes("long")) {
    return `${base} Provide a detailed 10-mark style answer.`;
  }
  if (normalized.includes("simple")) {
    return `${base} Explain in very simple language.`;
  }
  if (normalized.includes("exam")) {
    return `${base} Suggest important exam questions related to the topic.`;
  }
  return base;
}
