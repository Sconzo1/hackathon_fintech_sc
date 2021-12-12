import { BN, isBN } from 'bn.js'

declare global {
    interface Number {
        withDecimals(decimals?: number): BN
    }
}

Number.prototype.withDecimals = function (this: Number, decimals: number = 18) {
    return new BN(this.toString() + '0'.repeat(decimals))
}

export type VMException = {
    reason: string
}

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

export function assertEqBN(actual: BN | number | string, expected: BN | number | string, message?: string): void {
    assert.equal(actual.toString(), expected.toString(), message)
}

export function assertEqBNArray(actual: BN[] | number[] | string[], expected: BN[] | number[] | string[],
                                message?: string, withSort: boolean = false): void {
    actual = actual.map(v => new BN(v))
    expected = expected.map(v => new BN(v))

    if (withSort) {
        actual.sort((a,b) => a.cmp(b))
        expected.sort((a,b) => a.cmp(b))
    }

    assert.equal(actual.toString(), expected.toString(), message)
}

