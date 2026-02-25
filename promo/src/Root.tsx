import { Composition, Still } from "remotion";
import { HowItWorks } from "./HowItWorks";
import { HowItWorksV2 } from "./HowItWorksV2";
import { HowItWorksV3 } from "./HowItWorksV3";
import { HowItWorksV4 } from "./HowItWorksV4";
import { HowItWorksV5 } from "./HowItWorksV5";
import { HowItWorksV6 } from "./HowItWorksV6";
import { WerComparison } from "./WerComparison";
import { CostComparison } from "./CostComparison";
import { PrivacyComparison } from "./PrivacyComparison";
import { MenuBarDemo } from "./MenuBarDemo";
import { Logo } from "./Logo";
import {
  LogoDraw,
  LogoBounce,
  LogoReveal,
  LogoFloat,
  LogoStates,
} from "./LogoAnimated";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Still
        id="Logo"
        component={Logo}
        width={1024}
        height={1024}
      />
      <Composition
        id="LogoDraw"
        component={LogoDraw}
        durationInFrames={90}
        fps={30}
        width={1024}
        height={1024}
      />
      <Composition
        id="LogoBounce"
        component={LogoBounce}
        durationInFrames={75}
        fps={30}
        width={1024}
        height={1024}
      />
      <Composition
        id="LogoReveal"
        component={LogoReveal}
        durationInFrames={75}
        fps={30}
        width={1024}
        height={1024}
      />
      <Composition
        id="LogoFloat"
        component={LogoFloat}
        durationInFrames={120}
        fps={30}
        width={1024}
        height={1024}
      />
      <Composition
        id="LogoStates"
        component={LogoStates}
        durationInFrames={120}
        fps={30}
        width={1024}
        height={1024}
      />
      <Composition
        id="HowItWorks"
        component={HowItWorks}
        durationInFrames={600}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="HowItWorksV2-ProblemSolution"
        component={HowItWorksV2}
        durationInFrames={1800}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="HowItWorksV3-SplitScreen"
        component={HowItWorksV3}
        durationInFrames={840}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="HowItWorksV4-Typewriter"
        component={HowItWorksV4}
        durationInFrames={900}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="HowItWorksV5-Dynamic"
        component={HowItWorksV5}
        durationInFrames={810}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="HowItWorksV6-TransitionSeries"
        component={HowItWorksV6}
        durationInFrames={872}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="WerComparison"
        component={WerComparison}
        durationInFrames={180}
        fps={30}
        width={1200}
        height={630}
      />
      <Composition
        id="CostComparison"
        component={CostComparison}
        durationInFrames={210}
        fps={30}
        width={1200}
        height={630}
      />
      <Composition
        id="PrivacyComparison"
        component={PrivacyComparison}
        durationInFrames={210}
        fps={30}
        width={1200}
        height={630}
      />
      <Composition
        id="MenuBarDemo"
        component={MenuBarDemo}
        durationInFrames={300}
        fps={30}
        width={1200}
        height={630}
      />
    </>
  );
};
