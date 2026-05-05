# Codebase Structure

**Analysis Date:** 2025-05-05

## Directory Layout

```
zimage.swift/
├── Sources/
│   ├── ZImage/                             # Main library (MLX diffusion framework)
│   │   ├── Pipeline/                       # Generation and ControlNet pipelines
│   │   ├── Model/                          # Neural network components (Transformer, TextEncoder, VAE)
│   │   │   ├── Transformer/                # DiT model blocks and utilities
│   │   │   ├── TextEncoder/                # Qwen-based text encoder with vision support
│   │   │   │   ├── LLMGeneration/          # Token generation for prompt enhancement
│   │   │   │   └── Vision/                 # Vision transformer blocks
│   │   │   └── VAE/                        # Variational autoencoder for image compression
│   │   ├── Weights/                        # Model loading and weight mapping
│   │   ├── LoRA/                           # Low-rank adaptation layers
│   │   ├── Quantization/                   # Model compression utilities
│   │   ├── Tokenizer/                      # Text tokenization wrapper
│   │   ├── Util/                           # Image I/O and utilities
│   │   └── Support/                        # Metadata, model resolution, hub snapshots
│   └── ZImageCLI/                          # Command-line executable
├── Tests/
│   ├── ZImageTests/                        # Unit tests
│   │   ├── Config/                         # Config parsing tests
│   │   ├── Weights/                        # Weights/LoRA loader tests
│   │   ├── Scheduler/                      # Scheduler tests
│   │   ├── Quantization/                   # Quantization tests
│   │   ├── ImageIO/                        # Image I/O tests
│   │   └── LLMGeneration/                  # Prompt enhancement tests
│   ├── ZImageIntegrationTests/             # Full pipeline tests (requires models)
│   └── ZImageE2ETests/                     # CLI end-to-end tests
├── Package.swift                            # Swift Package Manager manifest
├── Package.resolved                         # Dependency lock file
├── CLAUDE.md                                # This Claude instructions file
└── README.md                                # Project documentation
```

## Directory Purposes

**Sources/ZImage/Pipeline/:**
- Purpose: High-level generation orchestration and request handling
- Contains: ZImagePipeline, ZImageControlPipeline, FlowMatchScheduler, utilities
- Key files:
  - `ZImagePipeline.swift` (700+ lines): Standard text-to-image generation with caching
  - `ZImageControlPipeline.swift` (500+ lines): ControlNet with inpainting support
  - `FlowMatchScheduler.swift`: Timestep schedule and Euler denoising step
  - `PipelineSnapshot.swift`: HuggingFace hub snapshot caching
  - `PipelineUtilities.swift`: Prompt encoding, image I/O routing

**Sources/ZImage/Model/Transformer/:**
- Purpose: Diffusion Transformer (DiT) architecture implementation
- Contains: Main transformer blocks, attention mechanisms, embeddings
- Key files:
  - `ZImageTransformer2D.swift`: Main DiT with noise/context refiners (100+ lines)
  - `ZImageTransformerBlock.swift`: Individual transformer block with modulation
  - `ZImageSelfAttention.swift`: Unified attention with KV cache
  - `ZImageFinalLayer.swift`: Output projection with optional modulation
  - `ZImageFeedForward.swift`: FFN sublayer
  - `ZImageTimestepEmbedder.swift`: Timestep → embedding projection
  - `ZImageRopeEmbedder.swift`: Rotary position embeddings
  - `ZImageAttentionUtils.swift`: Shared attention utilities
  - `ZImageCoordinateUtils.swift`: RoPE coordinate generation
  - `ZImageControlTransformer2D.swift`: ControlNet variant
  - `ZImageControlTransformerBlock.swift`: ControlNet attention block
  - `TransformerCacheBuilder.swift`: KV cache management

**Sources/ZImage/Model/TextEncoder/:**
- Purpose: Qwen-based semantic text encoder with optional vision tower
- Contains: LLM encoder, layer definitions, token generation
- Key files:
  - `TextEncoder.swift`: QwenTextEncoder main class (150+ lines)
  - `LLMGeneration/QwenGeneration.swift`: Token generation for prompt enhancement
  - `LLMGeneration/KVCache.swift`: Key-value cache for inference
  - `LLMGeneration/Sampling.swift`: Sampling strategies (top-k, top-p)
  - `Vision/QwenVisionTower.swift`: Vision encoder (optional multimodal)
  - `Vision/QwenVisionBlock.swift`, `.../Attention.swift`, `.../MLP.swift`: Vision components

**Sources/ZImage/Model/VAE/:**
- Purpose: Variational Autoencoder for image ↔ latent conversion
- Contains: Encoder/decoder blocks, attention, configuration
- Key files:
  - `AutoencoderKL.swift`: Full VAE with encode/decode (300+ lines)
    - Configurable block channels, layer depths
    - Self-attention for bottleneck
    - Quantization support

**Sources/ZImage/Weights/:**
- Purpose: Model weight loading, safetensors parsing, quantization awareness
- Contains: Mappers, loaders, readers, configs, utilities
- Key files:
  - `ZImageWeightsMapper.swift`: Route standard/quantized loading (100+ lines)
  - `WeightsMapping.swift`: Apply loaded tensors to model components
  - `SafeTensorsReader.swift`: Binary safetensors format parser
  - `WeightsLoader.swift`: Low-level safetensors streaming I/O
  - `ModelConfigs.swift`: Decodable config structs (120+ lines)
    - `ZImageTransformerConfig`, `ZImageVAEConfig`, `ZImageSchedulerConfig`, `ZImageTextEncoderConfig`
  - `ModelPaths.swift`: File enumeration (textEncoderWeights, transformerWeights, vaeWeights, etc.)
  - `ZImageWeightsParameters.swift`: Quantization parameter tracking
  - `WeightsAudit.swift`: Shape validation before applying weights
  - `ModelResolution.swift`: HuggingFace ID resolution and caching
  - `HubSnapshot.swift`: Local cache directory management

**Sources/ZImage/LoRA/:**
- Purpose: Low-rank weight adaptation over transformer layers
- Contains: Configuration, loading, application, utilities
- Key files:
  - `LoRAConfiguration.swift`: Source (local/HuggingFace) + scale; factory methods (100+ lines)
  - `LoRAWeightLoader.swift`: Load safetensors and download from HF
  - `LoRAApplicator.swift`: Inject low-rank updates into transformer blocks
  - `LoRAKeyMapper.swift`: Map weight names to target layers
  - `LoRALinear.swift`: Low-rank decomposed linear layer (down + up projection)

**Sources/ZImage/Quantization/:**
- Purpose: Weight compression for reduced memory footprint
- Contains: Specs, manifests, quantizer implementations
- Key files:
  - `ZImageQuantization.swift`: Specs, manifests, error types (100+ lines)
    - Supports: 4-bit, 8-bit quantization with group-wise affine/mxfp4 modes
    - Manifest JSON tracks which layers are quantized

**Sources/ZImage/Tokenizer/:**
- Purpose: Text → token ID conversion
- Contains: Qwen tokenizer wrapper
- Key files:
  - `Tokenizer.swift`: Configuration and loading

**Sources/ZImage/Util/:**
- Purpose: Utility functions for image I/O and common operations
- Contains: Image encoding/decoding
- Key files:
  - `ImageIO.swift`: PNG/JPEG encoding via CoreGraphics

**Sources/ZImage/Support/:**
- Purpose: Static metadata and cache management
- Contains: Model facts, hub resolution
- Key files:
  - `ModelMetadata.swift`: Dimensions, hyperparameters, defaults (50 lines)
  - `ModelResolution.swift`: Resolve HuggingFace model IDs to local paths
  - `HubSnapshot.swift`: Cache directory location

**Sources/ZImageCLI/:**
- Purpose: Command-line interface
- Contains: Argument parsing, subcommand routing
- Key files:
  - `main.swift`: Entry point (660 lines)
    - Subcommands: generate (default), control, quantize, quantize-controlnet
    - Argument parsing and validation
    - Request construction

**Tests/ZImageTests/:**
- Purpose: Unit tests for core components
- Contains: Config, weights, scheduler, quantization, imageIO, prompt enhancement tests
- Examples:
  - `Config/ModelConfigsTests.swift`: JSON config parsing
  - `Weights/SafeTensorsReaderTests.swift`: Safetensors binary format
  - `Weights/LoRALoaderTests.swift`: LoRA loading and validation
  - `Scheduler/FlowMatchSchedulerTests.swift`: Timestep schedule correctness
  - `Quantization/QuantizationTests.swift`: Quantization spec validation
  - `ImageIO/ImageIOTests.swift`: PNG/JPEG save/load
  - `LLMGeneration/PromptEnhancementTests.swift`: Text generation for prompts

**Tests/ZImageIntegrationTests/:**
- Purpose: Full pipeline tests requiring model weights
- Contains: Pipeline, ControlNet, LoRA, performance tests
- Examples:
  - `PipelineIntegrationTests.swift`: End-to-end generation
  - `ControlNetIntegrationTests.swift`: ControlNet conditioning with inpainting
  - `LoRAIntegrationTests.swift`: LoRA composition and dynamic application
  - `PerformanceTests.swift`: Memory/speed benchmarks
- Note: Requires downloading actual model weights (slow, memory-intensive)

**Tests/ZImageE2ETests/:**
- Purpose: Command-line end-to-end tests
- Contains: CLI argument parsing and subcommand execution
- Examples:
  - `CLIEndToEndTests.swift`: Test all CLI paths

## Key File Locations

**Entry Points:**
- `Sources/ZImageCLI/main.swift`: CLI entry point (call ZImageCLI.run())
- `Sources/ZImage/Pipeline/ZImagePipeline.swift`: Library API entry point (async loadModel() + generate())

**Configuration:**
- `Package.swift`: Swift Package Manager targets and dependencies
- `Sources/ZImage/Weights/ModelConfigs.swift`: Model architecture hyperparameters (JSON decodable)
- `Sources/ZImage/Support/ModelMetadata.swift`: Static model facts (dimensions, defaults)

**Core Logic:**
- `Sources/ZImage/Pipeline/ZImagePipeline.swift`: Standard generation loop + model state management
- `Sources/ZImage/Pipeline/ZImageControlPipeline.swift`: ControlNet variant + inpainting
- `Sources/ZImage/Model/Transformer/ZImageTransformer2D.swift`: Main DiT forward pass
- `Sources/ZImage/Model/TextEncoder/TextEncoder.swift`: Text → embeddings
- `Sources/ZImage/Model/VAE/AutoencoderKL.swift`: Latent ↔ image conversion
- `Sources/ZImage/Weights/ZImageWeightsMapper.swift`: Safetensors → MLXArray loading

**Testing:**
- `Tests/ZImageTests/`: Unit tests (no model weights needed)
- `Tests/ZImageIntegrationTests/`: Full pipeline tests (requires models)
- `Tests/ZImageE2ETests/`: CLI tests

## Naming Conventions

**Files:**
- Pattern: PascalCase.swift (e.g., `ZImagePipeline.swift`, `AutoencoderKL.swift`)
- Prefixes:
  - `ZImage*`: Core components (pipelines, models, weights, quantization)
  - `QwenTextEncoder*`: Text encoder and language model components
  - `Qwen*`: Qwen-specific implementations
  - No prefix: Utilities, intermediate types (FlowMatchScheduler, VAEConfig)

**Directories:**
- Pattern: PascalCase directories for functional groupings (Pipeline/, Model/, Weights/)
- Nested: Specialized components grouped by parent domain (Model/Transformer/, TextEncoder/Vision/)

**Types:**
- Classes: PascalCase (ZImagePipeline, QwenTextEncoder, AutoencoderKL)
- Structs: PascalCase (ZImageGenerationRequest, FlowMatchEulerScheduler, LoRAConfiguration)
- Enums: PascalCase (PipelineError, LoRAError, LoRASource)
- Protocols: PascalCase (Module via MLXNN)
- Configurations: PascalCase ending in "Config" (ZImageTransformerConfig, VAEConfig)

**Functions/Methods:**
- Pattern: camelCase
- Prefixes:
  - `load*`: Loading operations (loadModel, loadTokenizer, loadVAE)
  - `apply*`: Weight application (applyTransformer, applyDynamically)
  - `*AsFunction`: Callable types (callAsFunction in modules)
  - `encode/decode`: Text/image conversions

**Properties:**
- Pattern: camelCase
- Flags: `is*`, `has*` (isModelLoaded, hasLoRALoaded)

## Where to Add New Code

**New Feature:**
- **Primary code location:** `Sources/ZImage/Pipeline/` (for pipeline changes) or `Sources/ZImage/Model/` (for architecture changes)
- **Tests location:** `Tests/ZImageIntegrationTests/` (if requires model weights) or `Tests/ZImageTests/` (if unit test)
- **CLI changes:** `Sources/ZImageCLI/main.swift` (argument parsing + subcommand handler)
- **Example:** To add depth control variant:
  1. Create `Sources/ZImage/Model/Transformer/ZImageDepthControlTransformer2D.swift`
  2. Create pipeline in `Sources/ZImage/Pipeline/ZImageDepthControlPipeline.swift` (analog to ZImageControlPipeline)
  3. Add CLI subcommand in `Sources/ZImageCLI/main.swift` (depth-control case)
  4. Add integration test: `Tests/ZImageIntegrationTests/DepthControlIntegrationTests.swift`

**New Model Component/Module:**
- **Implementation:** `Sources/ZImage/Model/[ComponentType]/[ComponentName].swift`
- **Weights loading:** Add file paths to `Sources/ZImage/Weights/ModelPaths.swift`
- **Config struct:** Update `Sources/ZImage/Weights/ModelConfigs.swift` if new parameters needed
- **Weight application:** Add case in `Sources/ZImage/Weights/WeightsMapping.swift`
- **Example:** To add new normalization layer:
  1. Create `Sources/ZImage/Model/Transformer/ZImageCustomNorm.swift` (MLX Module subclass)
  2. Reference in `ZImageTransformerBlock.swift` where needed
  3. Add weight loading in WeightsMapping if has parameters

**Utilities & Shared Helpers:**
- **Shared helpers:** `Sources/ZImage/Util/` (image operations) or component-specific files
- **Cross-component utilities:** `Sources/ZImage/Support/` (metadata, resolution)
- **Example:** To add new image preprocessing:
  1. Create `Sources/ZImage/Util/ImagePreprocessing.swift`
  2. Call from pipeline: `let processed = ImagePreprocessing.cannyEdge(input: controlImage)`

**Tests:**
- **Unit tests:** `Tests/ZImageTests/[ComponentType]/[ComponentName]Tests.swift`
  - No model weights needed; test logic and I/O
- **Integration tests:** `Tests/ZImageIntegrationTests/[Feature]IntegrationTests.swift`
  - Full pipeline with actual weights
  - Slower, requires ~10GB+ VRAM
- **Example:** To add LoRA scale validation test:
  1. Create `Tests/ZImageTests/LoRA/LoRAScaleValidationTests.swift`
  2. Use existing fixtures from ZImage library

## Special Directories

**Sources/ZImage/Model/TextEncoder/Vision/:**
- Purpose: Vision tower for multimodal text encoding
- Generated: No (hand-written Swift)
- Committed: Yes
- Contains: Patch embedding, transformer blocks, attention for visual inputs
- Usage: Optional enhancement for vision-conditioned generation

**Sources/ZImage/Model/TextEncoder/LLMGeneration/:**
- Purpose: Token generation for prompt enhancement (Qwen LLM inference)
- Generated: No (hand-written Swift)
- Committed: Yes
- Contains: KV cache, sampling strategies (top-k, top-p, nucleus)
- Usage: Enhance user prompts via LLM before encoding

**.build/:**
- Purpose: Xcode build artifacts
- Generated: Yes (by xcodebuild)
- Committed: No (.gitignored)
- Contains: Compiled binaries, dependency sources, intermediate objects

**Tests/ZImageIntegrationTests/Resources/:**
- Purpose: Fixture data for integration tests
- Generated: No (hand-written or external fixture images)
- Committed: Yes
- Contains: Sample control images, masks, expected outputs

---

*Structure analysis: 2025-05-05*
