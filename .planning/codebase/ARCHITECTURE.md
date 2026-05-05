# Architecture

**Analysis Date:** 2025-05-05

## Pattern Overview

**Overall:** Layered Pipeline Architecture (MLX-based Diffusion Model)

**Key Characteristics:**
- Text-to-image diffusion generation with ControlNet support
- Model loading/caching with lazy initialization
- Weight mapper pattern for safetensors to MLX translation
- Dynamic LoRA composition over transformer blocks
- Flow matching scheduling for iterative denoising
- Async request-based API with progress callbacks

## Layers

**CLI Layer:**
- Purpose: Command-line interface for image generation, quantization, and control
- Location: `Sources/ZImageCLI/main.swift`
- Contains: Argument parsing, subcommand routing (generate, control, quantize, quantize-controlnet), request construction
- Depends on: ZImage library (pipelines, quantization, utilities)
- Used by: End users via command-line invocation

**Pipeline Layer (Public API):**
- Purpose: High-level generation orchestration with request handling and progress reporting
- Location: `Sources/ZImage/Pipeline/`
  - `ZImagePipeline.swift`: Standard text-to-image generation
  - `ZImageControlPipeline.swift`: ControlNet-conditioned generation with inpainting
  - `FlowMatchScheduler.swift`: Euler scheduler for diffusion steps
  - `PipelineSnapshot.swift`: Model repository/cache management
  - `PipelineUtilities.swift`: Shared utilities (prompt encoding, image I/O)
- Contains: Request types, generation loops, model loading state machines, LoRA composition, progress callbacks
- Depends on: Model, Weights, Tokenizer, VAE, LoRA, Scheduler, ImageIO
- Used by: CLI, external integrations (library consumers)

**Model Layer (Neural Architecture):**
- Purpose: Core diffusion model components
- Location: `Sources/ZImage/Model/`
- Contains:
  - **Transformer** (`Transformer/`): Main DiT (Diffusion Transformer) with noise/context refiners and unified attention
  - **TextEncoder** (`TextEncoder/`): Qwen-based LLM encoder with vision tower support
  - **VAE** (`VAE/`): AutoencoderKL for latent encoding/decoding
- Depends on: MLX, MLXNN, MLXFAST
- Used by: Pipeline for forward passes during generation

**Weights & Configuration Layer:**
- Purpose: Model weight loading, safetensors parsing, quantization awareness
- Location: `Sources/ZImage/Weights/`
- Contains:
  - `ZImageWeightsMapper.swift`: Routes to standard/quantized loading
  - `WeightsMapping.swift`: Applies loaded tensors to model components
  - `SafeTensorsReader.swift`: Binary safetensors file parsing
  - `ModelConfigs.swift`: JSON config structs for transformer/VAE/scheduler/text encoder
  - `ModelPaths.swift`: File path enumeration
  - `WeightsLoader.swift`: Lower-level safetensors streaming
  - `ZImageWeightsParameters.swift`: Quantization parameter tracking
  - `WeightsAudit.swift`: Validation of weight shapes
- Depends on: ModelConfigs, SafeTensors format parsing
- Used by: Pipeline during model loading

**LoRA Layer:**
- Purpose: Dynamic rank-based weight adaptation over transformer
- Location: `Sources/ZImage/LoRA/`
- Contains:
  - `LoRAConfiguration.swift`: Local/HuggingFace source specification
  - `LoRAWeightLoader.swift`: Load LoRA weights from safetensors or remote
  - `LoRAApplicator.swift`: Apply LoRA as dynamic layers on transformer blocks
  - `LoRAKeyMapper.swift`: Map weight names to correct layer targets
  - `LoRALinear.swift`: Low-rank decomposed linear layer
- Depends on: SafeTensors, Hub (for HuggingFace downloads), LoRAConfiguration
- Used by: Pipeline's loadLoRAs method, transformer forward pass if active

**Quantization Layer:**
- Purpose: Reduce model memory footprint via weight compression
- Location: `Sources/ZImage/Quantization/`
- Contains:
  - `ZImageQuantization.swift`: Quantization specs, manifests, error types
  - CLI quantize/quantize-controlnet subcommands for offline compression
- Depends on: MLX quantization utilities, SafeTensors I/O
- Used by: Weights mapper (loads quantized vs standard)

**Tokenizer Layer:**
- Purpose: Text to token IDs conversion using Qwen tokenizer
- Location: `Sources/ZImage/Tokenizer/`
- Contains: `Tokenizer.swift` (wrapper/configuration)
- Depends on: HuggingFace swift-transformers package
- Used by: Pipeline's encodePrompt flow

**Utilities & Support:**
- Purpose: Shared infrastructure
- Location: `Sources/ZImage/Util/`, `Sources/ZImage/Support/`
- Contains:
  - `ImageIO.swift`: PNG/JPEG image encoding/decoding
  - `ModelMetadata.swift`: Static model facts (dimensions, recommended params)
  - `ModelResolution.swift`: HuggingFace repo resolution
  - `HubSnapshot.swift`: Cache directory management
- Used by: All layers

## Data Flow

**Standard Text-to-Image (ZImagePipeline.generate):**

1. **Request Construction** (CLI → Pipeline)
   - User provides: prompt, output size, steps, guidance, seed, optional LoRA configs
   - Creates `ZImageGenerationRequest` struct

2. **Model Loading**
   - `loadModel(modelSpec)` → Download/cache via HuggingFace Hub if not present
   - Parse JSON configs → `ZImageModelConfigs` (transformer, VAE, scheduler, text encoder)
   - `ZImageWeightsMapper` decides: load quantized or standard weights
   - Load safetensors → MLXArray tensors
   - Apply weights to model instances via `ZImageWeightsMapping`
   - Cache tokenizer, textEncoder, transformer, VAE in pipeline state

3. **Text Encoding**
   - `encodePrompt(prompt)` → Tokenizer → Token IDs
   - Token IDs → `QwenTextEncoder` → Embeddings (batch_size, seq_len, hidden_dim)
   - Negative prompt encoded similarly (or blank if not provided)
   - Embeddings masked based on attention

4. **LoRA Loading** (if configured)
   - For each LoRA config:
     - `LoRAWeightLoader.load()` → Fetch safetensors
     - `LoRAApplicator.applyDynamically()` → Inject low-rank updates into transformer blocks
     - Store in `currentLoRAs` list

5. **Generation Loop (Denoising)**
   - Initialize latents: random noise (height/8, width/8, 16 channels) or from image
   - `FlowMatchEulerScheduler` generates timestep schedule
   - For each step:
     - Prepare timestep embedding
     - Forward through transformer: latents + embeddings + timestep → noise prediction
     - Apply scheduler step: `latents += noise_prediction * dt`
     - Report progress callback
   - After loop: latents contain denoised representation

6. **VAE Decoding**
   - `AutoencoderKL.decode(latents)` → RGB pixels (height, width, 3)
   - Denormalize to [0, 255]

7. **Output**
   - `QwenImageIO.saveImage()` → PNG/JPEG to disk
   - Return file path URL

**ControlNet-Conditioned Generation (ZImageControlPipeline.generate):**

- Similar flow as above, but:
  - Load additional `ZImageControlTransformer2D` with ControlNet weights
  - Preprocess control image (Canny/depth/pose/MLSD edge detection)
  - For inpainting: blend original image with random noise via mask
  - During denoising loop: inject control encoder output into main transformer
  - Control scale parameter modulates guidance strength

**State Management:**

- **Pipeline-level:** Caches entire model (tokenizer, textEncoder, transformer, VAE) across requests
  - `unloadModel()`: Full cleanup (memory optimization between different model IDs)
  - `unloadLoRAs()`: Clear only LoRA layers (fast, preserves transformer)
  - `unloadTransformer()`: Keep VAE/tokenizer/textEncoder, drop transformer (memory optimization mid-pipeline)
- **Quantization awareness:** `ZImageQuantizationManifest` tells weightsMapper which files are quantized
- **LoRA state:** Stored as `[(config, weights)]` tuple list; dynamic layer added at forward time

## Key Abstractions

**ZImageGenerationRequest:**
- Purpose: Encapsulates all generation parameters
- Examples: `Sources/ZImage/Pipeline/ZImagePipeline.swift` lines 10-57
- Pattern: Value type with default parameters, used for both pipeline.generate() and programmatic calls

**ZImageWeightsMapper:**
- Purpose: Route safetensors loading via standard or quantized path
- Examples: `Sources/ZImage/Weights/ZImageWeightsMapper.swift`
- Pattern: Struct with snapshot URL; queries quantization manifest; delegates to WeightsLoader or Quantizer

**LoRAConfiguration:**
- Purpose: Specify LoRA source (local path or HuggingFace ID) with optional scale
- Examples: `Sources/ZImage/LoRA/LoRAConfiguration.swift`
- Pattern: Enum LoRASource with factory methods (.local(), .huggingFace()); scale clamped [0, 1]

**FlowMatchEulerScheduler:**
- Purpose: Compute timestep schedule and denoising step formula
- Examples: `Sources/ZImage/Pipeline/FlowMatchScheduler.swift`
- Pattern: Value type (no mutable state); init computes full schedule; step() applies Euler formula

**ZImageTransformer2DModel:**
- Purpose: Main DiT architecture with modulation, refiners, and unified attention
- Examples: `Sources/ZImage/Model/Transformer/ZImageTransformer2D.swift`
- Pattern: MLX Module subclass; modular blocks; separate noise/context refiners; caching for KV

**QwenTextEncoder:**
- Purpose: Convert text to semantic embeddings via LLM
- Examples: `Sources/ZImage/Model/TextEncoder/TextEncoder.swift`
- Pattern: MLX Module with configurable layer depth; optional vision tower for multimodal

## Entry Points

**CLI Primary (ZImageCLI.run):**
- Location: `Sources/ZImageCLI/main.swift:30`
- Triggers: `xcodebuild build -scheme ZImageCLI` or direct binary execution
- Responsibilities:
  - Parse command-line arguments
  - Dispatch to subcommand handler (generate, control, quantize, quantize-controlnet)
  - Create request object
  - Instantiate pipeline
  - Execute generate() asynchronously with DispatchSemaphore synchronization
  - Write output and handle errors

**Library API (ZImagePipeline):**
- Location: `Sources/ZImage/Pipeline/ZImagePipeline.swift:59`
- Triggers: Imported by external Swift packages or CLI
- Responsibilities:
  - Public init() → async loadModel() → async generate(request)
  - State machine: lazily load tokenizer → textEncoder → transformer → VAE
  - Support for LoRA composition via loadLoRAs()
  - Progress callbacks at each major stage

**Quantization Entry:**
- Location: `Sources/ZImageCLI/main.swift:89-99` (quantize subcommand)
- Triggers: `ZImageCLI quantize -i input -o output --bits 8`
- Responsibilities:
  - Validate input directory and quantization parameters
  - Call `ZImageQuantizer.quantizeAndSave()`
  - Write quantization.json manifest alongside quantized weights

## Error Handling

**Strategy:** Throwing errors bubble up from model/weights loading; pipeline returns typed errors or throws

**Patterns:**

- **Model Loading:** `PipelineError` enum (lines 60-70 of ZImagePipeline.swift)
  - `.notImplemented`, `.tokenizerNotLoaded`, `.textEncoderNotLoaded`, `.transformerNotLoaded`, `.vaeNotLoaded`, `.weightsMissing()`, `.loraError()`
  - Mapped from lower-layer errors (LoRAError, SafeTensorsError)

- **LoRA:** `LoRAError` enum with specific cases: `.fileNotFound()`, `.invalidFormat()`, `.incompatibleWeights()`, `.downloadFailed()`, `.noSafetensorsFound()`

- **Quantization:** `ZImageQuantizationError` with safetensors not found, invalid parameters, output directory creation

- **SafeTensors:** Custom error types in SafeTensorsReader for corrupt headers or missing tensors

- **Async Handling:** Task-based generation wrapped in DispatchSemaphore for CLI synchronization

## Cross-Cutting Concerns

**Logging:** 
- Framework: `swift-log` (apple/swift-log)
- Pattern: Each major component instantiates `Logger(label: "z-image.component")` passed to initializers
- Usage: loadModel(), weightMapper, pipeline stages report .info/.warning/.error

**Validation:**
- Model config validation happens during JSON decode with throwing initializers
- Weight shape validation in WeightsAudit before applying to modules
- Quantization parameter validation in CLI subcommand handlers (bits ∈ {4,8}, groupSize ∈ {32,64,128})
- LoRA rank/alpha consistency checked on load

**Memory Management:**
- GPU cache cleared via `GPU.clearCache()` after unload operations
- Progressive unload hierarchy: full unloadModel() vs targeted unloadTransformer() vs unloadLoRAs()
- Pipeline tracks `isModelLoaded` flag to skip redundant loads of same model ID

**Concurrency:**
- Async/await for model loading (HuggingFace downloads, file I/O)
- CLI uses nonisolated(unsafe) DispatchSemaphore to block main for async pipeline.generate()
- LoRA dynamic application is synchronous but guarded by loaded state checks

---

*Architecture analysis: 2025-05-05*
