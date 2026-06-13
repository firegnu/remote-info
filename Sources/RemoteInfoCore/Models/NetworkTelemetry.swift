import Foundation

public struct NetworkTelemetry: Equatable, Sendable {
    public let interfaceName: String
    public let operstate: String
    public let receiveBytesPerSecond: Int64
    public let transmitBytesPerSecond: Int64
    public let receiveErrors: Int64
    public let transmitErrors: Int64
    public let receiveDrops: Int64
    public let transmitDrops: Int64

    public init(
        interfaceName: String,
        operstate: String,
        receiveBytesPerSecond: Int64,
        transmitBytesPerSecond: Int64,
        receiveErrors: Int64,
        transmitErrors: Int64,
        receiveDrops: Int64,
        transmitDrops: Int64
    ) {
        self.interfaceName = interfaceName
        self.operstate = operstate
        self.receiveBytesPerSecond = receiveBytesPerSecond
        self.transmitBytesPerSecond = transmitBytesPerSecond
        self.receiveErrors = receiveErrors
        self.transmitErrors = transmitErrors
        self.receiveDrops = receiveDrops
        self.transmitDrops = transmitDrops
    }

    public var errorCount: Int64 {
        receiveErrors + transmitErrors
    }

    public var dropCount: Int64 {
        receiveDrops + transmitDrops
    }
}
