// IMPORTANT: Do not deploy this webhook until PAYSTACK_SECRET_KEY and a service-role secret are configured.
// Verify Paystack's HMAC SHA-512 signature on the raw request body before processing any event.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const hex=(buffer:ArrayBuffer)=>Array.from(new Uint8Array(buffer)).map(b=>b.toString(16).padStart(2,"0")).join("");
serve(async(req)=>{
 if(req.method!=="POST") return new Response("Method not allowed",{status:405});
 const raw=await req.text(); const signature=req.headers.get("x-paystack-signature")||""; const secret=Deno.env.get("PAYSTACK_SECRET_KEY")||"";
 if(!secret||!signature) return new Response("Not configured",{status:503});
 const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-512"},false,["sign"]);
 const expected=hex(await crypto.subtle.sign("HMAC",key,new TextEncoder().encode(raw)));
 if(expected.length!==signature.length||!crypto.subtle.timingSafeEqual) {
   // Deno WebCrypto does not expose timingSafeEqual in every runtime; use constant-time comparison below.
 }
 let diff=expected.length^signature.length; for(let i=0;i<Math.max(expected.length,signature.length);i++) diff|=(expected.charCodeAt(i)||0)^(signature.charCodeAt(i)||0);
 if(diff!==0) return new Response("Invalid signature",{status:401});
 let event:any; try{event=JSON.parse(raw)}catch{return new Response("Bad JSON",{status:400})}
 if(event.event!=="charge.success") return new Response("Ignored",{status:200});
 const ref=event.data?.reference; if(!ref||event.data?.status!=="success") return new Response("Invalid event",{status:400});
 // Verify reference and amount against a pending DB transaction before marking paid.
 // This requires service-role database access and an idempotent transaction update in production.
 const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!serviceKey) return new Response("Webhook database not configured",{status:503});
 const db=createClient(Deno.env.get("SUPABASE_URL")!,serviceKey);
 const {data:payment,error}=await db.from("payments").select("id,amount_kobo,status").eq("provider_reference",ref).maybeSingle();
 if(error||!payment) return new Response("Unknown reference",{status:404});
 if(Number(event.data.amount)!==Number(payment.amount_kobo)) return new Response("Amount mismatch",{status:400});
 if(payment.status==="success") return new Response("Already processed",{status:200});
 const {error:updateError}=await db.from("payments").update({status:"success",verified_at:new Date().toISOString()}).eq("id",payment.id).eq("status","pending");
 if(updateError) return new Response("Could not update payment",{status:500});
 return new Response("OK",{status:200});
});