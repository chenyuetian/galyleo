import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Easy to Use',
    Svg: require('@site/static/img/jupyter.svg').default,
    description: (
      <>
        Launch Jupyter on high-performance computing systems at the San
        Diego Supercomputer Center with a simple command-line interface.
      </>
    ),
  },
  {
    title: 'Flexible Software Environments',
    Svg: require('@site/static/img/software-envs.svg').default,
    description: (
      <>
        Create software environments for any notebook session. Use
        environment modules, conda environments, or Singularity
        containers.
      </>
    ),
  },
  {
    title: 'Secured by Satellite',
    Svg: require('@site/static/img/apache.svg').default,
    description: (
      <>
        Secured by the Apache-based Satellite Reverse Proxy Service
        developed at the San Diego Supercomputer Center.
      </>
    ),
  },
];

function Feature({title, Svg, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
