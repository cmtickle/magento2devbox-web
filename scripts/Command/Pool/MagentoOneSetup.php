<?php
/**
 * Copyright © 2013-2017 Magento, Inc. All rights reserved.
 * See COPYING.txt for license details.
 */
namespace MagentoDevBox\Command\Pool;

use MagentoDevBox\Command\AbstractCommand;
use MagentoDevBox\Command\Options\MagentoOne as MagentoOptions;
use MagentoDevBox\Command\Options\DbOne as DbOptions;
use MagentoDevBox\Command\Options\WebServer as WebServerOptions;
use MagentoDevBox\Command\Options\RabbitMq as RabbitMqOptions;
use MagentoDevBox\Library\Registry;
use MagentoDevBox\Library\XDebugSwitcher;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

/**
 * Command for Magento installation
 */
class MagentoOneSetup extends AbstractCommand
{
    /**
     * {@inheritdoc}
     */
    protected function configure()
    {
        $this->setName('magentoone:setup')
            ->setDescription('Install Magento One')
            ->setHelp('This command allows you to install Magento One.');

        parent::configure();
    }

    /**
     * {@inheritdoc}
     */
    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $magentoPath = $input->getOption(MagentoOptions::PATH);

        $webserverHomePort = $this->requestOption(WebServerOptions::HOME_PORT, $input, $output);
        $magentoHost = $input->getOption(MagentoOptions::HOST);
        $magentoBackendPath = $this->requestOption(MagentoOptions::BACKEND_PATH, $input, $output);
        $magentoAdminUser = $this->requestOption(MagentoOptions::ADMIN_USER, $input, $output);
        $magentoAdminPassword = $this->requestOption(MagentoOptions::ADMIN_PASSWORD, $input, $output);

        $command = sprintf(
            'cd %s && php -f install.php -- '.
            '--license_agreement_accepted "yes" '.
            '--locale "en_US" '.
            '--timezone "America/Los_Angeles" '.
            '--default_currency "USD" '.
            '--url "http://%s:%s/" '.
            '--db_host "%s" '.
            '--db_name "%s" '.
            '--db_user "%s" '.
            '--db_pass "%s" '.
            '--skip_url_validation '.
            '--use_rewrites "yes" '.
            '--use_secure "no" '.
            '--secure_base_url "" '.
            '--use_secure_admin "no" '.
            '--admin_firstname "Magento" '.
            '--admin_lastname "User" '.
            '--admin_email "user@example.com" '.
            '--admin_username "%s" '.
            '--admin_password "%s" '.
            '--admin_frontname "%s"',
            $magentoPath,
            $magentoHost,
            $webserverHomePort,
            $input->getOption(DbOptions::HOST),
            $input->getOption(DbOptions::NAME),
            $input->getOption(DbOptions::USER),
            $input->getOption(DbOptions::PASSWORD),
            $magentoAdminUser,
            $magentoAdminPassword,
            $magentoBackendPath
        );

        $this->executeCommands($command, $output);

        Registry::setData(
            [
                MagentoOptions::HOST => $magentoHost,
                MagentoOptions::PORT => $webserverHomePort,
                MagentoOptions::BACKEND_PATH => $magentoBackendPath,
                MagentoOptions::ADMIN_USER => $magentoAdminUser,
                MagentoOptions::ADMIN_PASSWORD => $magentoAdminPassword
            ]
        );

        if (!Registry::get(static::CHAINED_EXECUTION_FLAG)) {
            $output->writeln('To prepare magento sources run <info>m2init magento:finalize</info> command next');
        }
    }

    /**
     * {@inheritdoc}
     */
    public function getOptionsConfig()
    {
        return [
            MagentoOptions::HOST => MagentoOptions::get(MagentoOptions::HOST),
            MagentoOptions::PATH => MagentoOptions::get(MagentoOptions::PATH),
            MagentoOptions::BACKEND_PATH => MagentoOptions::get(MagentoOptions::BACKEND_PATH),
            MagentoOptions::ADMIN_USER => MagentoOptions::get(MagentoOptions::ADMIN_USER),
            MagentoOptions::ADMIN_PASSWORD => MagentoOptions::get(MagentoOptions::ADMIN_PASSWORD),
            MagentoOptions::SAMPLE_DATA_INSTALL => MagentoOptions::get(MagentoOptions::SAMPLE_DATA_INSTALL),
            DbOptions::HOST => DbOptions::get(DbOptions::HOST),
            DbOptions::USER => DbOptions::get(DbOptions::USER),
            DbOptions::PASSWORD => DbOptions::get(DbOptions::PASSWORD),
            DbOptions::NAME => DbOptions::get(DbOptions::NAME),
            WebServerOptions::HOME_PORT => WebServerOptions::get(WebServerOptions::HOME_PORT),
            RabbitMqOptions::SETUP => RabbitMqOptions::get(RabbitMqOptions::SETUP),
            RabbitMqOptions::HOST => RabbitMqOptions::get(RabbitMqOptions::HOST),
            RabbitMqOptions::PORT => RabbitMqOptions::get(RabbitMqOptions::PORT)
        ];
    }
}
