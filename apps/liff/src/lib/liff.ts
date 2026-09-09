import liff from "@line/liff";

let initPromise: Promise<void> | null = null;

// See GitHub issue #11 (LINE Login integration).
export function initLiff(): Promise<void> {
  if (!initPromise) {
    initPromise = liff.init({ liffId: process.env.NEXT_PUBLIC_LIFF_ID! });
  }
  return initPromise;
}

export { liff };
