import { Configurator } from "@/components/Configurator/Configurator";
import { Footer } from "@/components/Footer/Footer";
import { Navigation } from "@/components/Navigation/Navigation";
import { StoryStage } from "@/components/StoryStage/StoryStage";
import { StoryStatic } from "@/components/StoryStage/StoryStatic";
import { RevealObserver } from "@/components/Reveal";

export default function HomePage() {
  return (
    <>
      <Navigation />
      <main id="inhalt">
        <StoryStage />
        <StoryStatic />
        <Configurator />
      </main>
      <Footer />
      <RevealObserver />
    </>
  );
}
