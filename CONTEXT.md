# Z-Image.swift

A text-to-image generation library and CLI for Apple Silicon, providing diffusion-based image synthesis with support for model customization and image-conditioned generation.

## Language — Consumer

**Pipeline**:
The stateful orchestrator that loads a model and performs image generation. Comes in two variants: standard (text-to-image) and control (image-conditioned).
_Avoid_: Engine, generator, runner

**Model**:
A downloadable artifact (directory of config files + weight files) identified by a HuggingFace ID or local path.
_Avoid_: Checkpoint, snapshot, weights (when referring to the whole artifact)

**Component**:
An individual neural network within a loaded model — Text Encoder, Transformer, VAE, Tokenizer, or Scheduler.
_Avoid_: Module (internal implementation term), layer, network

**LoRA**:
A lightweight weight overlay applied to the transformer that modifies generation style or behavior. Stackable, each with an independent scale (0.0–1.0). Compatible with a specific model architecture.
_Avoid_: Adapter, fine-tune, plugin

**ControlNet**:
The image-conditioned generation mode that uses a specialized transformer to accept a control image (edge map, depth map, pose) for spatial guidance. Requires separate ControlNet weights and runs through the control pipeline.
_Avoid_: Conditioning, guided generation

**Quantization**:
A one-time model preparation step that reduces weight precision (4-bit or 8-bit) to decrease memory usage. The pipeline loads quantized models transparently.
_Avoid_: Compression, optimization

**Prompt Enhancement**:
An optional preprocessing step where the text encoder is used as a language model to expand a short prompt into a more detailed description. Costs additional VRAM (~5GB).
_Avoid_: Prompt rewriting, prompt expansion, upsampling

**Denoising**:
The iterative process of refining random noise into a coherent image via the transformer and scheduler.
_Avoid_: Sampling, diffusion (as a verb)

**Step**:
One iteration of the denoising loop. More steps generally means higher quality but slower generation.
_Avoid_: Iteration, tick

**Guidance Scale**:
How strongly generation follows the prompt. Z-Image-Turbo is distilled for zero guidance (default 0.0), making this mostly vestigial.
_Avoid_: CFG, classifier-free guidance (in user-facing contexts)

**Latents**:
The compressed internal representation of an image. Image dimensions are divided by 8 to produce latent dimensions — width and height should be multiples of 8.
_Avoid_: Embeddings (which refers to text), feature maps

## Language — Contributor

**Noise Refiner**:
Initial transformer blocks that process the noisy image stream before it meets text conditioning.
_Avoid_: Pre-processing blocks

**Context Refiner**:
Transformer blocks that process the text embeddings before they meet the image stream.
_Avoid_: Text blocks, caption refiner

**Main Layers**:
The unified attention blocks where image and text streams interact after refinement.
_Avoid_: Core layers, attention layers (too generic)

**ROPE (Rotary Position Embedding)**:
Positional encoding used in attention, with separate axes for spatial dimensions (height, width) and temporal/sequence dimensions.
_Avoid_: Positional encoding (too generic)

**Flow Matching**:
The scheduler algorithm — Euler discrete steps over a learned velocity field. Distinct from score-based diffusion (DDPM/DDIM).
_Avoid_: Diffusion schedule (implies score-based)

**Patch Embedding**:
The mechanism that converts latents into token sequences for the transformer by dividing them into patches.
_Avoid_: Tokenization (reserved for text)

**Weight Mapping**:
The translation layer between safetensors file key names and Swift module parameter paths.
_Avoid_: Key mapping (ambiguous with LoRA key mapping)

## Relationships

- A **Pipeline** loads exactly one **Model** at a time
- A **Model** is composed of five **Components**: Tokenizer, Text Encoder, Transformer, VAE, Scheduler
- **Components** split into weighted (Text Encoder, Transformer, VAE) and stateless (Tokenizer, Scheduler)
- **LoRAs** are applied to the **Pipeline**'s Transformer after the base **Model** is loaded
- Multiple **LoRAs** can be active simultaneously on one **Pipeline**
- **Quantization** transforms a **Model** into a quantized **Model** (offline, before loading)
- **ControlNet** requires the control **Pipeline** variant, separate weights, and a control image
- **Prompt Enhancement** runs before **Denoising** — it rewrites the prompt, then encoding proceeds normally
- The **Transformer** architecture is: **Noise Refiners** → **Context Refiners** → **Main Layers**
- **Flow Matching** scheduler computes timesteps and sigmas consumed by the **Denoising** loop
- **Latents** are produced by **Patch Embedding** into tokens for the **Transformer**, and decoded by the **VAE** into pixels

## Example dialogue

> **User:** "I loaded a model and applied two LoRAs, but the output looks wrong."
> **Dev:** "Are both LoRAs compatible with this model? Check the LoRA validation — they target specific transformer architectures."
> **User:** "Can I use ControlNet with LoRAs?"
> **Dev:** "Yes, but you need the control pipeline. Load your model, apply LoRAs, then run generation with a control image and ControlNet weights."

> **Contributor:** "Why does the transformer have three groups of blocks instead of one stack?"
> **Lead:** "The noise refiners and context refiners process image and text independently first. Only the main layers do unified attention between them — this is the Z-Image architecture."

## Flagged ambiguities

- "model" was used to mean both the downloadable artifact and individual neural network components — resolved: **Model** is the artifact, **Component** is each neural network within it.
- "weights" was used to mean both full model weight files and LoRA weight overlays — resolved: use **Model** for base weights, **LoRA** for overlays, "weights" only in technical/file contexts.
- "snapshot" appeared in code (`PipelineSnapshot`) but is an implementation detail — not a domain term.
