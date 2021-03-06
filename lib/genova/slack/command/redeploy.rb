module Genova
  module Slack
    module Command
      class Redeploy < SlackRubyBot::Commands::Base
        class << self
          def call(client, data, match)
            logger.info("Execute redeploy command: (UNAME: #{client.owner}, user=#{data.user})")
            logger.info("Input command: #{match['command']} #{match['expression']}")

            history = Genova::Slack::History.new(data.user).last
            bot = Genova::Slack::Bot.new(client.web_client)

            if history.present?
              bot.post_confirm_deploy(
                type: history[:type],
                account: history[:account],
                repository: history[:repository],
                branch: history[:branch],
                cluster: history[:cluster],
                base_path: history[:base_path],
                run_task: history[:run_task],
                service: history[:service],
                scheduled_task_rule: history[:scheduled_task_rule],
                scheduled_task_target: history[:scheduled_task_target],
                confirm: true
              )
            else
              e = Exceptions::NotFoundError.new('History does not exist.')
              bot.post_error(error: e, slack_user_id: data.user)
            end
          end
        end
      end
    end
  end
end
