import Anthropic from "@anthropic-ai/sdk";
import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { auth as authV1 } from "firebase-functions/v1";

import { normalize, ScanSchema, SYSTEM_PROMPT, userPrompt, validateRequest } from "./scan";

initializeApp();

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

/** Scans per signed-in user per day (UTC). Keeps costs predictable. */
const DAILY_LIMIT = 25;

async function takeQuota(uid: string): Promise<void> {
  const day = new Date().toISOString().slice(0, 10);
  const ref = getFirestore().doc(`scanUsage/${uid}_${day}`);
  await getFirestore().runTransaction(async (tx) => {
    const used = ((await tx.get(ref)).get("count") as number | undefined) ?? 0;
    if (used >= DAILY_LIMIT) {
      throw new HttpsError("resource-exhausted", `You've used today's ${DAILY_LIMIT} scans. Try again tomorrow.`);
    }
    tx.set(ref, { uid, day, count: FieldValue.increment(1) }, { merge: true });
  });
}

/**
 * Callable: { image: base64, mediaType, hint? } → { is_food, items[], note }.
 * Requires Firebase Auth; the API key never leaves the server.
 */
export const scanFood = onCall(
  { secrets: [anthropicKey], region: "asia-south1", memory: "512MiB", timeoutSeconds: 120, enforceAppCheck: false },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in to scan food.");

    let input: ReturnType<typeof validateRequest>;
    try {
      input = validateRequest(request.data);
    } catch (e) {
      throw new HttpsError("invalid-argument", (e as Error).message);
    }
    await takeQuota(request.auth.uid);

    const client = new Anthropic({ apiKey: anthropicKey.value() });
    try {
      const response = await client.beta.messages.parse({
        model: "claude-opus-5-5",
        max_tokens: 16000,
        output_config: { effort: "medium", format: betaZodOutputFormat(ScanSchema) },
        // If a safety classifier declines, the API retries on a suitable model.
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: input.mediaType, data: input.image } },
              { type: "text", text: userPrompt(input.hint) },
            ],
          },
        ],
      });

      if (response.stop_reason === "refusal") {
        throw new HttpsError("failed-precondition", "This photo couldn't be analysed. Try another photo or add the food manually.");
      }
      if (response.stop_reason === "max_tokens" || !response.parsed_output) {
        logger.warn("scanFood: no parsed output", { stop: response.stop_reason });
        throw new HttpsError("internal", "Couldn't read that photo. Please try again.");
      }
      return normalize(response.parsed_output);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      if (e instanceof Anthropic.RateLimitError) {
        throw new HttpsError("unavailable", "The scanner is busy. Please try again in a minute.");
      }
      if (e instanceof Anthropic.BadRequestError) {
        logger.error("scanFood: bad request", { message: e.message });
        throw new HttpsError("invalid-argument", "That image couldn't be processed. Try a JPEG photo.");
      }
      if (e instanceof Anthropic.APIError) {
        logger.error("scanFood: API error", { status: e.status, message: e.message });
        throw new HttpsError("unavailable", "The scanner is temporarily unavailable.");
      }
      throw e;
    }
  },
);

/** Deletes a user's scan counters when their account is deleted. */
export const cleanupUser = authV1.user().onDelete(async (user) => {
  const db = getFirestore();
  const docs = await db.collection("scanUsage").where("uid", "==", user.uid).get();
  const batch = db.batch();
  docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  logger.info("cleanupUser: removed scan counters", { count: docs.size });
});
