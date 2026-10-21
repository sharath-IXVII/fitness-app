import { z } from "zod";

/** What the model returns for one photo. Kept free of numeric bounds so it
 * stays within what structured outputs accept; ranges are enforced in
 * `normalize` instead. */
export const ScanSchema = z.object({
  is_food: z.boolean().describe("False if the photo does not show food or drink."),
  items: z.array(
    z.object({
      name: z.string().describe("Short dish or ingredient name, e.g. 'Paneer butter masala'."),
      portion: z.string().describe("Visible portion in everyday units, e.g. '1 katori (150 g)'."),
      grams: z.number().describe("Estimated edible weight in grams."),
      kcal: z.number(),
      protein_g: z.number(),
      carbs_g: z.number(),
      fat_g: z.number(),
      fiber_g: z.number(),
      veg: z.enum(["vegan", "veg", "egg", "non_veg"]).describe("Most likely diet class of this item."),
      confidence: z.enum(["high", "medium", "low"]),
    }),
  ),
  note: z.string().describe("One short sentence on what was hard to judge (hidden oil, portion depth), or empty."),
});

export type Scan = z.infer<typeof ScanSchema>;

export const SYSTEM_PROMPT = `You estimate nutrition from a single photo of a meal for a fitness app used mostly in India.

Identify each distinct food or drink on the plate and estimate its edible weight from visual cues (plate and katori size, \
cutlery, hands, packaging). Then estimate calories, protein, carbohydrate, fat and fiber for that weight using standard \
nutrition references for the dish as typically prepared at home or in Indian restaurants, including likely cooking oil, \
ghee or butter you can see.

Be honest about uncertainty: use "low" confidence when the dish is ambiguous or the portion is hard to judge, and say \
what was hard in the note. Do not invent items you cannot see. If the photo shows no food or drink, set is_food to false \
and return no items. Users can correct every value afterwards, so give your single best estimate rather than ranges.`;

export function userPrompt(hint?: string): string {
  const h = hint?.trim().slice(0, 200);
  return h ? `Estimate the nutrition of this meal. The user says: "${h}"` : "Estimate the nutrition of this meal.";
}

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type ImageType = (typeof ALLOWED_TYPES)[number];

/** Base64 of ~3.75 MB of image data; the app sends ~1280 px JPEGs well below this. */
export const MAX_BASE64_LENGTH = 5_000_000;

export function validateRequest(data: unknown): { image: string; mediaType: ImageType; hint?: string } {
  const d = (data ?? {}) as Record<string, unknown>;
  const image = d.image;
  const mediaType = d.mediaType;
  if (typeof image !== "string" || image.length === 0) throw new RangeError("image is required");
  if (image.length > MAX_BASE64_LENGTH) throw new RangeError("image is too large");
  if (!/^[A-Za-z0-9+/]+=*$/.test(image)) throw new RangeError("image must be base64 without a data: prefix");
  if (typeof mediaType !== "string" || !(ALLOWED_TYPES as readonly string[]).includes(mediaType)) {
    throw new RangeError("mediaType must be image/jpeg, image/png or image/webp");
  }
  const hint = typeof d.hint === "string" ? d.hint : undefined;
  return { image, mediaType: mediaType as ImageType, hint };
}

const clamp = (v: number, lo: number, hi: number) => (Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : lo);
const round1 = (v: number) => Math.round(v * 10) / 10;

/** Clamps model output to physically sensible ranges and rounds it. */
export function normalize(scan: Scan): Scan {
  const items = scan.is_food
    ? scan.items.slice(0, 12).map((i) => ({
        ...i,
        name: i.name.trim().slice(0, 60) || "Food",
        portion: i.portion.trim().slice(0, 60),
        grams: Math.round(clamp(i.grams, 0, 3000)),
        kcal: Math.round(clamp(i.kcal, 0, 5000)),
        protein_g: round1(clamp(i.protein_g, 0, 300)),
        carbs_g: round1(clamp(i.carbs_g, 0, 600)),
        fat_g: round1(clamp(i.fat_g, 0, 300)),
        fiber_g: round1(clamp(i.fiber_g, 0, 100)),
      }))
    : [];
  return { is_food: scan.is_food && items.length > 0, items, note: scan.note.trim().slice(0, 240) };
}
