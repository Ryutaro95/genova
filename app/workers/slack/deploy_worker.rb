module Slack
  class DeployWorker
    include Sidekiq::Worker

    sidekiq_options queue: :slack_deploy, retry: false

    def perform(id)
      logger.info('Started Slack::DeployWorker')

      deploy_job = DeployJob.find(id)
      deploy_client = Genova::Deploy::Client.new(
        Genova::Deploy::Client.mode.find_value(:slack).to_sym,
        deploy_job[:repository],
        account: deploy_job[:account],
        branch: deploy_job[:branch],
        cluster: deploy_job[:cluster],
        deploy_job_id: id
      )
      bot = Genova::Slack::Bot.new

      begin
        history = Genova::Deploy::History.new(deploy_job[:slack_user_id])
        history.add(
          account: deploy_job[:account],
          repository: deploy_job[:repository],
          branch: deploy_job[:branch],
          cluster: deploy_job[:cluster],
          service: deploy_job[:service]
        )

        bot.post_detect_slack_deploy(
          deploy_job[:account],
          deploy_job[:repository],
          deploy_job[:branch],
          deploy_job[:cluster],
          deploy_job[:service]
        )

        bot.post_started_deploy(
          region: deploy_client.options[:region],
          cluster: deploy_job[:cluster],
          service: deploy_job[:service],
          jid: jid,
          deploy_job_id: id
        )
        task_definition = deploy_client.exec(deploy_job[:service], Settings.slack.deploy_lock_timeout)
        bot.post_finished_deploy(
          cluster: deploy_job[:cluster],
          service: deploy_job[:service],
          task_definition: task_definition,
          slack_user_id: deploy_job[:slack_user_id]
        )
      rescue => e
        bot.post_error(
          message: e.to_s,
          slack_user_id: deploy_job[:slack_user_id],
          deploy_job_id: id
        )
        deploy_client.cancel_deploy
        raise e
      end
    end
  end
end
