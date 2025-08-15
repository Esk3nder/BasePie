import Image from "next/image";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-100">
      <div className="container mx-auto px-4 py-12">
        <div className="flex items-center justify-between">
          <span className="text-2xl font-bold">AzFlin's EVM Starter Code</span>
          <ConnectButton></ConnectButton>
        </div>
        <div className="flex justify-center mt-4">
          <Image
            src={"/azflin.jpg"}
            alt={"azflin"}
            width={400}
            height={400}
            className="rounded-xl"
          ></Image>
        </div>
      </div>
    </main>
  );
}
