import Foundation
import MLX
import MLXNN

public struct LoRAEntry {
    public var down: MLXArray
    public var up: MLXArray
    public var scale: Float
}

public protocol DynamicLoRACapable: AnyObject {

    var loraEntries: [LoRAEntry] { get set }
}

extension DynamicLoRACapable {

    public func addLoRA(down: MLXArray, up: MLXArray, scale: Float) {
        loraEntries.append(LoRAEntry(down: down, up: up, scale: scale))
    }
    public func clearLoRA() {
        loraEntries.removeAll()
    }
    public var hasLoRA: Bool {
        !loraEntries.isEmpty
    }
    public func computeLoRAContribution(_ x: MLXArray) -> MLXArray? {
        guard !loraEntries.isEmpty else { return nil }
        var total: MLXArray?
        for entry in loraEntries {
            let loraHidden = MLX.matmul(x, entry.down.T)
            let loraOut = MLX.matmul(loraHidden, entry.up.T)
            let contribution = loraOut * entry.scale
            if let existing = total {
                total = existing + contribution
            } else {
                total = contribution
            }
        }
        return total
    }
}
public class LoRALinear: Linear, DynamicLoRACapable {
    public var loraEntries: [LoRAEntry] = []
    public convenience init(from linear: Linear) {
        self.init(weight: linear.weight, bias: linear.bias)
    }

    public override func callAsFunction(_ x: MLXArray) -> MLXArray {

        var result: MLXArray
        if let bias = bias {
            result = MLX.addMM(bias, x, weight.T)
        } else {
            result = MLX.matmul(x, weight.T)
        }
        if let loraContribution = computeLoRAContribution(x) {
            result = result + loraContribution.asType(result.dtype)
        }

        return result
    }
}
public class LoRAQuantizedLinear: QuantizedLinear, DynamicLoRACapable {
    public var loraEntries: [LoRAEntry] = []
    public convenience init(from quantizedLinear: QuantizedLinear) {
        self.init(
            weight: quantizedLinear.weight,
            bias: quantizedLinear.bias,
            scales: quantizedLinear.scales,
            biases: quantizedLinear.biases,
            groupSize: quantizedLinear.groupSize,
            bits: quantizedLinear.bits
        )
    }

    public override func callAsFunction(_ x: MLXArray) -> MLXArray {

        var result = MLX.quantizedMatmul(
            x,
            weight,
            scales: scales,
            biases: biases,
            transpose: true,
            groupSize: groupSize,
            bits: bits
        )

        if let bias = bias {
            result = result + bias
        }
        if let loraContribution = computeLoRAContribution(x) {
            result = result + loraContribution.asType(result.dtype)
        }

        return result
    }
}
