import { keccak256, toUtf8Bytes } from 'ethers/lib/utils'
export * as constants from "./constants"
export * as signatures from "./signatures"

export const id = (signature: string) => {
  return keccak256(toUtf8Bytes(signature)).slice(0, 10)
}