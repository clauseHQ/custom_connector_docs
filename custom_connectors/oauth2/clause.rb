{
  title: 'Clause',
  
  methods: {
    error_response: ->(code, body, header, message, resource){
      case code
      when 400
        error("Your request contained bad data.\n#{code}: #{message}\n#{body}")
      when 403
        error("You don't have access to the selected #{resource}. Please contact your organization administrator.")
      when 404
        error("The chosen #{resource} couldn't be found. Perhaps, it's been deleted?")
      when 422
        error("Your request contained bad data.\n#{code}: #{message}\n#{body}")
      else
        error("An unexpected error occured. Please contact the Clause support team: #{message}")
      end
    },
  },
  
  connection: {
    fields: [
      {
        name: "client_id",
        optional: false,
        label: "Client ID",
        hint: "To use this connector with Clause, you will need to register a client from your <a href='https://hub.clause.io/settings/organization/developers' target='_blank'>developer settings page</a> to generate the Client ID and Client Secret values. Populate the <i>Callback URL</i> field with https://www.workato.com/oauth/callback.",
      },
      {
        name: "client_secret",
        label: "Client Secret",
        optional: false,
        control_type: "password"
      }
    ],

    authorization: {
      type: 'oauth2',
      authorization_url: lambda do |connection|
        scopes = [
          "openid",
          "profile",
          "write:all",
          "offline_access"
        ].join(" ")

        "https://login.clause.io/authorize?client_id=" \
        "#{connection['client_id']}&response_type=code&audience=https://api.clause.io&scope=#{scopes}"
      end,
      
      acquire: lambda do |connection, auth_code, redirect_uri|
        response = post("https://login.clause.io/oauth/token").
                     payload(client_id: connection['client_id'],
                             client_secret: connection['client_secret'],
                             grant_type: "authorization_code",
                             code: auth_code,
                             redirect_uri: redirect_uri).
                     request_format_www_form_urlencoded
        [response, nil, {
          expiredToken: response["access_token"]
        }]
      end,
      
      credentials: ->(connection, access_token) {
        headers('Authorization': "Bearer #{access_token}")
      },
      
      refresh: lambda do |connection, refresh_token|
        post("https://login.clause.io/oauth/token", {
          client_id: connection['client_id'],
          grant_type: "refresh_token",
          expired_token: connection["expiredToken"],
          refresh_token: refresh_token
        })
      end,

      refresh_on: [
        401,
        "Unauthorized",
        /Unauthorized/
      ],
    },
    
    base_uri: lambda do |_connection|
      "https://api.clause.io"
    end
  },

  object_definitions: {
    # 
    # RESOURCE DEFINITIONS
    # 

    contract: {
      fields: ->() {
        [
          {
            name: 'id',
            type: :string,
            hint: 'A unique reference for the contract',
          },
          {
            name: 'name',
            type: :string,
            hint: 'The name of the contract to be created. An empty name will default to \'untitled\'.',
            default:'My New Workato Contract',
            optional: true
          },
          {
            name: 'markdown',
            type: :string,
            hint: 'The contents of the contract in <a href="https://docs.accordproject.org/docs/markup-cicero.html" target="_blank">CiceroMark<a/> format.',
            default: "The *Acceptance Criteria* are the specifications defined ...",
            optional: false
          },
          {
            name: 'status',
            type: :string,
            hint: 'One of either `DRAFTING`, `SIGNING`, `RUNNING`, `COMPLETED`.',
            optional: false
          },
          {
            name: 'createdAt',
            type: 'date_time',
            hint: 'When contract drafting was started.',
            optional: false
          },
          {
            name: 'updatedAt',
            type: 'date_time',
            hint: 'When the contract was last updated.',
            optional: false
          },
        ]
      },
    },

    # 
    # INPUT DEFINITIONS
    # 

    contract_created_input: {
      fields: ->() {
        [
          {
            name: 'since',
            type: :timestamp,
            hint: "When you start recipe for the first time, it picks up " \
            "trigger events from this specified date and time. Leave " \
            "empty to get events created one hour ago",
            optional: true
          },
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            hint: 'The target organization to watch for new contracts',
            pick_list: 'organizations',
            optional: false
          },
        ]
      },
    },

    contract_new_input: {
      fields: ->() {
        [
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            pick_list: 'organizations',
            hint: 'The target organization that the new contract will be created in.',
            optional: false
          },
          {
            name: 'name',
            type: :string,
            hint: 'The name of the contract to be created. An empty name will default to \'untitled\'.',
            default:'My New Workato Contract',
            optional: true
          },
          {
            name: 'markdown',
            type: :string,
            hint: 'The contents of the new contract in <a href="https://docs.accordproject.org/docs/markup-cicero.html" target="_blank">CiceroMark<a/> format.',
            default: "The *Acceptance Criteria* are the specifications defined ...",
            optional: false
          }
        ]
      },
    },

    contract_select_input: {
      fields: ->() {
        [
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            hint: 'The target organization where the source contract exists',
            pick_list: 'organizations',
            optional: false
          },
          {
            name: 'contract',
            type: :string,
            control_type:'select',
            hint: 'The contact that you want to connect to',
            pick_list: 'contracts',
            pick_list_params: { organization: 'organization' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "contract",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Contract ID",
            }
          },
        ]
      }
    },

    contract_get_file_input: {
      fields: ->() {
        [
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            hint: 'The target organization where the source contract exists',
            pick_list: 'organizations',
            optional: false
          },
          {
            name: 'contract',
            type: :string,
            control_type:'select',
            hint: 'The contact that you want to connect to',
            pick_list: 'contracts',
            pick_list_params: { organization: 'organization' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "contract",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Contract ID",
            }
          },
          {
            name: 'type',
            type: :string,
            control_type:'select',
            hint: 'The file type, either PDF or Markdown',
            pick_list: 'fileTypes',
            optional: false
          },
        ]
      }
    },

    obligation_emitted_input: {
      fields: ->() {
        [
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            hint: 'The target organization where the source contract exists',
            pick_list: 'organizations',
            optional: false
          },
          {
            name: 'contract',
            type: :string,
            control_type:'select',
            hint: 'The contact that you want to connect to',
            pick_list: 'contracts',
            pick_list_params: { organization: 'organization' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "contract",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Contract ID",
            }
          },
          {
            name: 'clause',
            type: :string,
            control_type:'select',
            hint: 'The clause that emits the relevant obligation',
            pick_list: 'clauses',
            pick_list_params: { contract: 'contract' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "clause",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Clause ID",
            }
          }
        ]
      }
    },

    flow_trigger_input: {
      fields: ->() {
        [
          {
            name: 'organization',
            type: :string,
            control_type:'select',
            hint: 'The target organization where the source contract exists',
            pick_list: 'organizations',
            optional: false
          },
          {
            name: 'contract',
            type: :string,
            control_type:'select',
            hint: 'The contact that you want to connect to',
            pick_list: 'contracts',
            pick_list_params: { organization: 'organization' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "contract",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Contract ID",
            }
          },
          {
            name: 'clause',
            type: :string,
            control_type:'select',
            hint: 'The clause that that you want to send data to',
            pick_list: 'clauses',
            pick_list_params: { contract: 'contract' },
            optional: false,
            toggle_hint: "Select from list",
            toggle_field: {
              name: "clause",
              type: :string,
              control_type: "text",
              optional: false,
              toggle_hint: "Use Clause ID",
            }
          },
          {
            name: 'flow',
            type: :string,
            control_type:'select',
            hint: 'The HTTP Trigger flow',
            pick_list: 'httpFlows',
            pick_list_params: { clause: 'clause' },
            optional: false
          },
          {
            name: 'flowToken',
            type: :string,
            hint: 'The Bearer token from the flow step',
            optional: false
          },
          {
            name: 'data',
            type: 'object',
            hint: 'A JSON object to send to the flow',
            optional: false
          }
        ]
      }
    },

    # 
    # OUTPUT DEFINITIONS
    # 

    contract_new_output: {
      fields: ->() {
        [
          {
            name: 'id',
            type: :string,
            hint: 'A unique reference for the newly created contract',
          }
        ]
      },
    },

    obligation_emitted_output: {
      fields: ->() {
        [
          {name: '$class', type: :string},
          {name: 'description', type: :string, hint: 'Only for Payment Obligations', optional: true},
          {name: 'amount', type: :object, properties: [
            { name: 'doubleValue', type: :double},
            { name: 'currencyCode', type: :string}
          ], hint: 'Only for Payment Obligations', optional: true},
          {name: 'title', type: :string, hint: 'Only for Notification Obligations', optional: true},
          {name: 'message', type: :string, hint: 'Only for Notification Obligations', optional: true},
          {name: 'contract', type: :string},
          {name: 'promisor', type: :string, hint: 'The party that should fulfil the obligation, often to make a payment', optional: true},
          {name: 'promisee', type: :string, hint: 'Often the recipient of a payment obligation', optional: true},
          {name: 'eventId', type: :string},
          {name: 'deadline', type: 'date_time', optional: true},
          {name: 'timestamp', type: 'date_time', hint: 'The time when the obligation was raised by the contract.'}
        ]
      }
    },

    contract_get_file_output: {
      fields: ->() {
        [
          {name: 'mimeType', type: :string},
          {name: 'content', type: :string, hint: 'Binary files (such as PDFs) are base64 encoded.'},
        ]
      }
    },

    flow_trigger_output: {
      fields: ->() {
        []
      }
    },

  },

  test: ->(connection) {
    get("/v1/users/me")
  },

  actions: {
    create_contract: {
      title: "Create a new contract",
      description: "Create a new <span class='provider'>contract</span> in " \
        "<span class='provider'>Clause</span>",
      input_fields: ->(object_definitions){
        object_definitions['contract_new_input']
      },
      execute: ->(connection, input) {
        contract = post('/v1/contracts?markdown=true', {
          organizationId: input['organization'],
          markdown: input['markdown'],
          name: input['name']
        }).
        after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
      },
      output_fields: ->(object_definitions) {
        object_definitions['contract_new_output']
      }
    },

    copy_contract: {
      title: "Copy a contract",
      description: "Copy an existing <span class='provider'>contract</span> in " \
        "<span class='provider'>Clause</span>",
      input_fields: ->(object_definitions){
        object_definitions['contract_select_input']
      },
      execute: ->(connection, input) {
        contract = post("/v1/contracts/#{input['contract']}/copy").
          after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
      },
      output_fields: ->(object_definitions) {
        object_definitions['contract']
      }
    },

    sign_contract: {
      title: "Sign a contract",
      description: "Attest that a <span class='provider'>contract</span> " \
        "has been signed outside of <span class='provider'>Clause</span>",
      help: "Signing a contract transitions it to 'RUNNING'",
      input_fields: ->(object_definitions){
        object_definitions['contract_select_input']
      },
      execute: ->(connection, input) {
        contract = post("/v1/contracts/#{input['contract']}/signatures/all-signed").
          after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
      },
      output_fields: ->(object_definitions) {
        object_definitions['contract']
      }
    },

    complete_contract: {
      title: "Complete a contract",
      description: "Completing a <span class='provider'>contract</span> " \
        " in <span class='provider'>Clause</span> stops it from receiving data and emitting events.",
      input_fields: ->(object_definitions){
        object_definitions['contract_select_input']
      },
      execute: ->(connection, input) {
        contract = post("/v1/contracts/#{input['contract']}/complete").
          after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
      },
      output_fields: ->(object_definitions) {
        object_definitions['contract']
      }
    },

    contract_get_file: {
      title: "Download a contract",
      description: "Retrieve a <span class='provider'>contract</span>'s" \
        " PDF or Markdown from <span class='provider'>Clause</span>.",
      input_fields: ->(object_definitions){
        object_definitions['contract_get_file_input']
      },
      execute: ->(connection, input) {
        content = nil
        mimeType = ''
        if input['type'] == 'pdf'
          content = get("/v1/contracts/#{input['contract']}/pdf").response_format_raw.
            after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
          mimeType = 'application/pdf'
        end
        if input['type'] == 'md'
          contract = get("/v1/contracts/#{input['contract']}").
            after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'contract') end
          content = contract['markdown']
          mimeType = 'text/plain'
        end
        {
          mimeType: mimeType,
          content: content,
        }
      },
      output_fields: ->(object_definitions) {
        object_definitions['contract_get_file_output']
      }
    },

    #  Disable until we can override the connections default authorization header
    # 
    # flow_trigger: {
    #   input_fields: ->(object_definitions){
    #     object_definitions['flow_trigger_input']
    #   },

    #   execute: ->(connection, input) {
    #     contract = post("https://api.clause.io/v1/flows/#{input['flow']}", input['data']).
    #       headers("Authorization": "Bearer #{input['token']}").
    #       after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'flow') end
    #   },

    #   output_fields: ->(object_definitions) {
    #     object_definitions['flow_trigger_output']
    #   }
    # },
  },

  triggers: {
    obligation_emitted: {
      type: :paging_desc,
      title: "Obligation emitted",
      description: "A Smart Clause emitted an obligation in <span class='provider'>Clause</span>.",
      input_fields: ->(object_definitions) {
        object_definitions['obligation_emitted_input']
      },
      webhook_subscribe: ->(webhook_url, connection, input, recipe_id){
        secretName = "WorkatoWebhook#{rand()}"
        secret = post("/v1/secrets?organizationId=#{input['organization']}",
          {
            '$class': 'io.clause.common.integration.HTTPConfig',
            'url': webhook_url,
            'name': secretName,
            'description': 'Workato, dynamic webhook url',
          }).
          after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'secret') end
        flow = post('/v1/flows',
          {
            'clauseId': input['clause'],
            'flowName': 'Workato Flow',
            'triggerType': 'Action',
            '$steps':[
              {
                'transformation': 'httpRequest',
                'input':{
                  'headers':[{'name':'Content-Type','value':'application/json'}],
                  'json': '{{% step[0].output %}}',
                  'method': 'POST',
                  'uri': "{{% vault['#{secretName}'].url %}}"
                }
              }
            ],
            'scheduleExpression':''
          }).
          after_error_response(/.*/) do |code, body, headers, message| call('error_response',code, body, headers, message, 'flow') end
        { flowId: flow['flowId'], secretId: secret['id'] }
      },
      webhook_notification: ->(input, payload){
        payload
      },
      webhook_unsubscribe: ->(webhook){
        delete("/v1/flows/#{webhook['flowId']}")
        delete("/v1/secrets/#{webhook['secretId']}")
      },
      dedup: ->(event){
        rand()
      },
      output_fields: ->(object_definitions) {
        object_definitions['obligation_emitted_output']
      },
      sample_output: ->(_connection, _input){
        {
          '$class': 'org.accordproject.cicero.runtime.PaymentObligation',
          'amount': {
              '$class': 'org.accordproject.money.MonetaryAmount',
              'doubleValue': 181.98,
              'currencyCode': 'USD'
          },
          'description': 'Penalty payment owed by Dan to Matt for delivery of fragile goods, including delays',
          'contract': 'resource:io.clause.demo.fragileGoods.FragileGoodsClause#3924',
          'promisor': 'resource:org.accordproject.cicero.contract.AccordParty#3333',
          'promisee': 'resource:org.accordproject.cicero.contract.AccordParty#1235',
          'deadline': '2019-08-31T09:43:20.743-04:00',
          'eventId': '28cd6b71-b399-11e9-a415-2f2abeed0243',
          'timestamp': '2019-07-31T09:43:20.743-04:00'
        }
      }
    },

    contract_created: {
      type: :paging_desc,
      title: "Contract created",
      description: "Respond to a new contract being drafted in <span class='provider'>Clause</span>",
      input_fields: ->(object_definitions) {
        object_definitions['contract_created_input']
      },
      poll: lambda do |connection, input, last_updated_since|
        updated_since = (input["since"] || 1.hour.ago)

        contracts = get("/v1/contracts?organizationId=#{input['organization']}").
          after_error_response(/.*/) do |code, body, headers, message|
            call('error_response',code, body, headers, message, 'contract')
          end.
          select do |contract|
            contract['createdAt'] >= updated_since
          end


        next_updated_since = contracts.last['createdAt'] unless contracts.blank?

        {
          events: contracts,
          next_poll: next_updated_since
        }
      end,
      dedup: lambda do |event|
        event['id']
      end,  
      output_fields: lambda do |object_definitions|
        object_definitions['contract']
      end
    },
  },

  pick_lists: {
    organizations: lambda do |connection|
      user = get("/v1/users/me").
        after_error_response(/.*/) do |code, body, headers, message| 
          call('error_response',code, body, headers, message, 'organizations')
        end
      user["organizations"].
        map { |org| [org["name"], org["id"]] }
    end,
    contracts: lambda do |connection, organization:|
      contracts = get("/v1/contracts?organizationId=#{organization}").
        after_error_response(/.*/) do |code, body, headers, message|
          call('error_response',code, body, headers, message, 'contract')
        end
      contracts.map { |contract| ["#{contract["name"]} (#{contract["id"]}) - #{contract["status"]}", contract["id"]] }
    end,
    clauses: lambda do |connection, contract:|
      contract = get("/v1/contracts/#{contract}").
        after_error_response(/.*/) do |code, body, headers, message| 
          call('error_response',code, body, headers, message, 'contract') 
        end
      contract["clauses"].
        map { |clauses| ["#{clauses["name"]} (#{clauses["id"]})", clauses["id"]] }
    end,
    flows: lambda do |connection, clause:|
      flows = get("/v1/flows?clauseId=/#{clause}").
        after_error_response(/.*/) do |code, body, headers, message| 
          call('error_response',code, body, headers, message, 'flow') 
        end
        flows.
          select { |flow| flow['triggerType'] == 'HTTP Trigger'}.
          map { |flow| [flow["flowName"], flow["flowId"]] }
    end,
    fileTypes: ->() {
      [ 
        [ "PDF", 'pdf'],
        [ "Markdown", 'md'],
      ]
    }
  },
}