<?php
/**
 * Copyright © 2013-2017 Magento, Inc. All rights reserved.
 * See COPYING.txt for license details.
 */
namespace MagentoDevBox\Command\Pool;

use MagentoDevBox\Command\AbstractCommand;
use MagentoDevBox\Command\Options\MagentoOne as MagentoOptions;
use MagentoDevBox\Command\Options\Composer as ComposerOptions;
use MagentoDevBox\Library\Registry;
use MagentoDevBox\Library\XDebugSwitcher;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

use Symfony\Component\Console\Input\InputOption;

/**
 * Command for downloading Magento One sources
 */
class MagentoOneDownload extends AbstractCommand
{
    /**
     * @var int
     */
    private $keysAvailabilityInterval = 40;

    /**
     * @var int
     */
    private $maxAttemptsCount = 10;

    /**
     * @var bool
     */
    private $sshKeyIsNew = false;


    /**
     * {@inheritdoc}
     */
    protected function configure()
    {
        $this->setName('magentoone:download')
            ->setDescription('Download Magento One sources')
            ->setHelp('This command allows you to download Magento One sources.');

        foreach($this->getOptionsConfig() as $name => $config) {
            if (!$this->getConfigValue('virtual', $config, static::OPTION_DEFAULT_VIRTUAL)) {
                $this->addOption(
                    $name,
                    $this->getConfigValue('shortcut', $config),
                    $this->getConfigValue('requireValue', $config, static::OPTION_DEFAULT_REQUIRE_VALUE)
                    && !$this->getConfigValue('boolean', $config, static::OPTION_DEFAULT_BOOLEAN)
                        ? InputOption::VALUE_REQUIRED
                        : InputOption::VALUE_OPTIONAL,
                    $this->getConfigValue('description', $config, ''),
                    $this->getConfigValue('default', $config)
                );
            }
        }
    }

    /**
     * Define whether dir is empty
     *
     * @param $dir
     * @return bool
     */
    private function isEmptyDir($dir)
    {
        return !count(glob("/$dir/*"));
    }

    /**
     * {@inheritdoc}
     *
     * @throws \Exception
     */
    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $enableSyncMarker = $input->getOption(MagentoOptions::ENABLE_SYNC_MARKER);

        if ($enableSyncMarker) {
            $statePath = $input->getOption(MagentoOptions::STATE_PATH);
            $syncMarkerPath =  $statePath . '/' . $enableSyncMarker;

            if (file_exists($syncMarkerPath)) {
                $this->executeCommands(sprintf('unlink %s', $syncMarkerPath), $output);
            }
        }

        $magentoPath = $input->getOption(MagentoOptions::PATH);
        $customAuth = '';

        $useExistingSources = $this->requestOption(MagentoOptions::SOURCES_REUSE, $input, $output)
            || !$this->isEmptyDir($magentoPath);

        if ($useExistingSources) {
            XDebugSwitcher::switchOff();
            $composerJsonExists = file_exists(sprintf('%s/composer.json', $magentoPath));
            if ($composerJsonExists) {
                $this->executeCommands(sprintf('cd %s && %s composer install', $magentoPath, $customAuth), $output);
            }
            XDebugSwitcher::switchOn();
        } else {
            $edition = 'ce';
            $version = $this->requestOption(MagentoOptions::VERSION, $input, $output);
            $version = strlen($version) > 0 ? $version : '1.9';

            XDebugSwitcher::switchOff();
            $this->executeCommands(
                [
                    sprintf(
                        'sudo sh -c "cd %s && git clone https://github.com/'
                        . 'engineyard/magento-%s-%s ."',
                        $magentoPath,
                        $edition,
                        $version
                    )
                ],
                $output
            );
            XDebugSwitcher::switchOn();
        }

        if (!Registry::get(static::CHAINED_EXECUTION_FLAG)) {
            $output->writeln('To setup magento run <info>m2init magentoone:setup</info> command next');
        }

        Registry::set(MagentoOptions::SOURCES_REUSE, $useExistingSources);
    }

    /**
     * Wrapper for shell_exec
     *
     * @param $command
     * @return string
     */
    private function shellExec($command)
    {
        return shell_exec($command);
    }

    /**
     * {@inheritdoc}
     */
    public function getOptionsConfig()
    {
        return [
            MagentoOptions::SOURCES_REUSE => MagentoOptions::get(MagentoOptions::SOURCES_REUSE),
            MagentoOptions::PATH => MagentoOptions::get(MagentoOptions::PATH),
            //MagentoOptions::EDITION => MagentoOptions::get(MagentoOptions::EDITION),
            MagentoOptions::VERSION => MagentoOptions::get(MagentoOptions::VERSION),
            MagentoOptions::STATE_PATH => MagentoOptions::get(MagentoOptions::STATE_PATH),
            MagentoOptions::ENABLE_SYNC_MARKER => MagentoOptions::get(MagentoOptions::ENABLE_SYNC_MARKER)
        ];
    }
}
