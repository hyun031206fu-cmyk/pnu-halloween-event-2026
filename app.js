import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.EVENT_CONFIG || {};
const isConfigured = config.supabaseUrl?.startsWith("https://") && config.supabaseAnonKey && !config.supabaseAnonKey.includes("YOUR_");
const supabase = isConfigured ? createClient(config.supabaseUrl, config.supabaseAnonKey) : null;
const eventSlug = config.eventSlug || "pnu-halloween-2026";
const dialog = document.querySelector("#apply-dialog");
const form = document.querySelector("#apply-form");
const message = document.querySelector("#form-message");

function sessionId() {
  let id = localStorage.getItem("pnu_halloween_session");
  if (!id) { id = crypto.randomUUID(); localStorage.setItem("pnu_halloween_session", id); }
  return id;
}

function campaignProperties() {
  const query = new URLSearchParams(location.search);
  const utm = Object.fromEntries(
    ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"]
      .filter((key) => query.has(key))
      .map((key) => [key, query.get(key)?.slice(0, 120)])
  );

  return {
    ...utm,
    landing_path: location.pathname,
    referrer_host: document.referrer ? new URL(document.referrer).host : null,
  };
}

async function track(name, properties = {}) {
  if (!supabase) return;
  const { error } = await supabase.from("event_events").insert({
    event_slug: eventSlug, session_id: sessionId(), event_name: name,
    path: location.pathname, referrer: document.referrer || null, properties
  });
  if (error) console.warn("Analytics event was not recorded:", error.message);
}

function trackInBackground(name, properties) {
  void track(name, properties).catch((error) => console.warn("Analytics request failed:", error));
}

document.querySelectorAll("[data-track]").forEach((element) => element.addEventListener("click", () => {
  trackInBackground(element.dataset.track, {
    element: element.tagName.toLowerCase(),
    label: element.textContent.trim().slice(0, 80),
    placement: element.closest("section")?.id || "dialog"
  });
}));
document.querySelectorAll("details[data-track-open]").forEach((element) => element.addEventListener("toggle", () => {
  if (element.open) trackInBackground(element.dataset.trackOpen, { placement: "faq" });
}));
document.querySelector("#open-apply").addEventListener("click", () => { dialog.showModal(); trackInBackground("application_started", { placement: "conversion_band" }); });
document.querySelector("#close-apply").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = new FormData(form);
  const submit = form.querySelector("button[type=submit]");
  submit.disabled = true;
  message.textContent = "신청을 처리하고 있어요…";
  try {
    if (!supabase) throw new Error("Supabase 설정이 아직 없습니다.");
    const { error } = await supabase.from("event_registrations").insert({
      event_slug: eventSlug, session_id: sessionId(), name: data.get("name"), contact: data.get("contact"), quantity: Number(data.get("quantity"))
    });
    if (error) throw error;
    await track("purchase_completed", { quantity: Number(data.get("quantity")), value: 0, currency: "KRW" });
    form.reset();
    message.textContent = "신청이 완료되었습니다. 곧 안내를 보내드릴게요!";
  } catch (error) {
    message.textContent = "신청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.";
    console.error(error);
  } finally { submit.disabled = false; }
});

trackInBackground("page_view", {
  ...campaignProperties(),
  title: document.title,
  viewport: `${window.innerWidth}x${window.innerHeight}`
});
