globals [
  ;; Food loss tracking
  total-food-loss
  pre-harvest-loss
  post-harvest-loss
  total-preharvest-loss
  total-postharvest-loss

  ;; Financial tracking
  total-profit
  market-price

  export-price

  ;; Environmental factors
  climate-shock-active?
  pest-outbreak-active?

  ;; Adaptation metrics
  quality-improvement-rate
  tech-adoption-rate

  ;; Default loss rates
  transport-loss
  storage-loss
  unsold-inventory

  ;; Demand-supply based prices
  market-demand
  base-price

  ;; Storage and season tracking
  storage-available?         ;; Determines if storage is available
  current-season-multiplier  ;; Track season effect
  current-quality-bonus      ;; Track quality effect

  ;; Commission and bidding
  commission-rate            ;; Commission rate for agents
  bidding-active?            ;; Track if bidding is happening
  season-length              ;; Length of the current season in ticks
  current-season             ;; Track the current season (e.g., 1, 2, 3, ...)

  ;; Contract-related
 ; contract-active?           ;; Track if contracts are active for farmers
  current-contractor         ;; Track the contractor assigned to a farmer
]

breed [farmers farmer]
breed [contractors contractor]
breed [commission-agents commission-agent]
breed [wholesalers wholesaler]
breed [retailers retailer]

directed-link-breed [transactions transaction]  ; Shows flow of goods

turtles-own [
  ; Core attributes
  profit
  inventory
  quality

  ; Farmer-specific
  farm-size
  risk-tolerance
  production-cost
  under-contract?

  ; Business agents
  operating-cost
  capital-available
    ;unsold-inventory
]

contractors-own [contract-active?]
links-own [
  transaction-volume
  transaction-value
  duration
]

; ======================
; SETUP PROCEDURES
; ======================

to setup
  clear-all
  set-default-shape farmers "person"
  set-default-shape contractors "truck"
  set-default-shape commission-agents "circle"
  set-default-shape wholesalers "car"
  set-default-shape retailers "house"

  ; Initialize globals
  set base-price 30
  set market-demand 1200  ;; or any baseline number you want
  set market-price 10
  set export-price 15
  set quality-improvement-rate 0.5
  set tech-adoption-rate 0.1
  set transport-loss 1.5
  set storage-loss 2
  set climate-shock-active? false
  set pest-outbreak-active? false
  set total-preharvest-loss 0
  set total-postharvest-loss 0
  set storage-available? true ;; or false, depending on the scenario
  set storage-available? true
  set unsold-inventory 0 ;; Initialize unsold inventory

  ; Create agents
  create-farmers 50 [ setup-farmer ]
  create-contractors 15 [ setup-contractor ]
  create-commission-agents 5 [ setup-commission-agent ]
  create-wholesalers 10 [ setup-wholesaler ]
  create-retailers 20 [ setup-retailer ]

  setup-transaction-network

  reset-ticks
  update-display
end

to setup-farmer
  set farm-size random-normal 100 25
   set under-contract? false ;; Initialize to no active contract by default
    set farm-size random 100 + 50  ;; Example initialization of farm-s
 set inventory min list
  (farm-size * random-normal 5 1)  ;; Production capacity based on farm size
  ((market-demand * 0.8) / count farmers)  ;; Align with 80% of market demand
set inventory max list 50 (farm-size * 0.8)  ;; Ensure a minimum floor of 10 units
  set quality max list 0 (random-normal 60 15)             ;; Ensure positive quality
  set risk-tolerance random-float 1.0
  set size farm-size / 50
  set color scale-color green inventory 30 100
  setxy random-xcor (min-pycor + random 10)
  ifelse farm-size > 100 [
    set production-cost random-normal 5 1 ; large farmers have economies of scale
    set label "L" ; large
  ] [
    set production-cost random-normal 10 2  ; increased for small farmers
    set label "S" ; small
  ]
  set profit 0
end

to setup-contractor
  setxy (random 15 - 7) (random-ycor)
  set color blue
 set capital-available max list 10000 (random-normal 25000 5000)  ; Minimum Rs.10000
  set operating-cost random-normal 300 50
  set inventory random-normal 500 100  ;; Start contractors with some inventory
  set profit 0
  set contract-active? false
end

to setup-commission-agent
  set color gray
  set capital-available random-normal 8000 1500
  set operating-cost random-normal 150 25  ;; Balanced operating costs
  set inventory random-normal 300 50  ;; Start with some inventory
  set profit 0
  set commission-rate random-normal 0.1 0.02  ;; Added commission rate
end

to setup-wholesaler
  setxy random-xcor (random 10 - 5)
  set color orange
  set operating-cost random-normal 300 50
  set inventory random-normal 1000 200  ;; Start wholesalers with some inventory
  set quality random-normal 60 10
  set profit 0
end

to setup-retailer
  setxy random-xcor (max-pycor - random 10)
  set shape "house"
  set size 1.5
  set color yellow
  set label "R"
  set label-color black
  set inventory random-normal 200 50  ;; Start retailers with some inventory
  set quality random-normal 50 15
  set profit 0
  set operating-cost random-normal 200 50
end
to setup-transaction-network
  ask farmers [
    if (inventory > 0) and (random-float 1.0 < (0.4 + (risk-tolerance * 0.3))) [
      ;; Calculate minimum viable deal size (5 units or 5% of inventory, whichever is larger)
      let min-deal-size 5
      let relative-deal inventory * (0.05 + (risk-tolerance * 0.05))
      let deal-size max (list min-deal-size relative-deal)

      ;; Ensure deal doesn't exceed farmer's inventory
      set deal-size min (list deal-size inventory)

      ;; Find contractors who:
      ;; 1. Can afford the deal (with 10% buffer)
      ;; 2. Have available capacity (<5 existing links)
      ;; 3. Are actively contracting
      let suitable-contractors contractors with [
        (capital-available >= (deal-size * market-price * 1.1)) and
        (count my-in-links < 5) and
        contract-active?
      ]

      if any? suitable-contractors [
        ;; Prefer contractors with more capital and fewer existing connections
        let chosen-contractor max-one-of suitable-contractors [
          capital-available - (count my-in-links * 1000)
        ]

        create-transaction-to chosen-contractor [
          set transaction-volume deal-size
          set transaction-value deal-size * market-price
          set duration random 4 + 2
          set color green
        ]

        ;; Immediate partial payment (30% advance)
        ask chosen-contractor [
          set capital-available capital-available - (deal-size * market-price * 0.3)
        ]

        print (word "Established contract: Farmer " who " -> Contractor " [who] of chosen-contractor
               " for " deal-size " units at " market-price " each")
      ]
    ]
  ]
end

; to setup-transaction-network
;
;  ask farmers [
;    if (inventory > 0) and (random-float 1.0 < (0.4 + (risk-tolerance * 0.3))) [
;      let deal-size max list 1 (inventory * (0.01 + (risk-tolerance * 0.02)))  ;; Smaller deal sizes
;      let suitable-contractors contractors with [
;        (capital-available > (deal-size * market-price * 1.1)) and
;        (count my-in-links < 5)
;      ]
;      if any? suitable-contractors [
;        let chosen-contractor one-of suitable-contractors
;        create-transaction-to chosen-contractor [
;          set transaction-volume deal-size
;          set transaction-value deal-size * market-price
;          set duration random 4 + 2
;        ]
;      ]
;    ]
;  ]
;end


; ======================
; MAIN LOOPf
; ======================
to go
  ;; === OBSERVER CONTEXT ===

  ;; Update market conditions every 2 ticks
  if ticks mod 2 = 0 [
    update-market-conditions
  ]

  ;; Check environmental risks every 5 ticks
  if ticks mod 5 = 0 [
    check-environmental-risks
  ]

  ;; Agents make decisions based on current prices

  ask contractors [
    contractor-decisions
  ]
   ask retailers [
    retailer-decisions
  ]
  ask farmers [
    farmer-decisions
  ]
  ask wholesalers [
    wholesaler-decisions
  ]


  ;; Essential updates every tick
  calculate-food-loss
  update-transactions

  ;; Update profit and unsold inventory at observer level
  set total-profit sum [profit] of turtles
  set unsold-inventory sum [inventory] of turtles with [inventory > 0]

  ;; Debugging information (optional)
  show (word "Tick: " ticks)
  show (word "Unsold Inventory: " unsold-inventory)
  show (word "Total Transactions: " count transactions)

  ;; Check for new deals every 3 ticks
  if ticks mod 3 = 0 [
    ask farmers [
      consider-new-contracts
    ]
  ]

  ;; Essential checks at the end of the season
  end-season
  to-check

  ;; Increment tick and update visuals
  tick
  update-display
  updateplots
end
to farmer-decisions
  let production 0
  let transaction-revenue 0
  let total-production-cost 0
  let total-storage-cost 0
  let total-spoilage-loss 0

  ;; Debugging: Print farmer's key variables
  print (word "Farmer: " who " Contract-Active?: " under-contract?)
  print (word "Quality: " quality " Production-Cost: " production-cost " Inventory: " inventory)

  if under-contract? [
    ;; === Production Logic ===
    let base-yield ifelse-value (label = "L") [0.10] [0.05]
    if is-number? quality [
      let max-production farm-size * (base-yield + (min list 1 (quality / 600)))
      set production min list (market-demand / (count farmers * 1.5)) max-production
      set inventory inventory + production
      print (word "Farmer " who " Produced: " production " New Inventory: " inventory)
    ]

    ;; === Transaction Logic ===
    ifelse inventory > 0 [
      print (word "Farmer " who " has inventory to make a deal.")

      ;; Calculate minimum acceptable price (20% above production cost)
      let min-acceptable-price production-cost * 1.2

      ifelse market-price >= min-acceptable-price [
        ;; Price is acceptable - proceed with transaction
        let eligible-contractors contractors with [
          [contract-active?] of self = true and
          [who] of self != [who] of myself
          and
          [capital-available] of self > (market-price * 10)  ;; Can afford at least 10 units
        ]

        ifelse any? eligible-contractors [
          let selected-contractor one-of eligible-contractors
          print (word "Farmer " who " Selected Contractor: " [who] of selected-contractor)

          ;; Calculate deal volume (minimum 5 units)
          let min-deal 5
          let max-possible-deal min list inventory ([inventory] of selected-contractor)
          let affordable-deal floor ([capital-available] of selected-contractor / market-price)

          let deal-volume max list min-deal (min list max-possible-deal affordable-deal)
          let deal-value deal-volume * market-price

          if deal-volume > 0 [
            ;; Execute transaction
            set inventory inventory - deal-volume
            set transaction-revenue deal-value
            set profit profit + deal-value

            ask selected-contractor [
              set inventory inventory + deal-volume
              set capital-available capital-available - deal-value
              set profit profit - deal-value
            ]

            print (word "Successful transaction: " deal-volume " units at " market-price)
            print (word "Farmer profit: " deal-value " | Contractor remaining capital: " [capital-available] of selected-contractor)
          ]
        ] [
          print (word "No eligible contractors with sufficient capital")
        ]
      ] [
        ;; Price too low - reject transaction
        print (word "Rejecting price " market-price " (needs at least " min-acceptable-price ")")
      ]
    ] [
      print (word "Farmer " who " has no inventory to make a deal.")
    ]

    ;; === Storage and Spoilage Costs ===
    let storage-cost-rate 0.02
    set total-storage-cost inventory * storage-cost-rate
    set profit profit - total-storage-cost
    print (word "Farmer " who " Storage Cost: " total-storage-cost)

    let spoilage-rate (1 - (quality / 100)) * 0.1
    set total-spoilage-loss inventory * spoilage-rate
    set inventory inventory - total-spoilage-loss
    print (word "Farmer " who " Spoilage Loss: " total-spoilage-loss)

    if is-number? production-cost and is-number? production [
      set total-production-cost production-cost * production
      set profit profit - total-production-cost
      print (word "Farmer " who " Total Production Cost: " total-production-cost)
    ]
  ]

  ;; === Visual Feedback ===
  set size 0.5 + (farm-size / 200)
  set color scale-color green quality 40 90
  set label-color ifelse-value (not under-contract?) [gray] [ifelse-value (profit > 0) [white] [red]]

  print (word "Farmer: " who " Decision Process Complete")
end

;;;;;;;;;;
;;;;;;;;;
;;;;;;;;;;
to contractor-decisions
  ;; === Evaluate Current Transactions ===
  print (word "Contractor " who ": Evaluating current transactions.")

  ask my-in-links [
       let transaction-profit transaction-value - (transaction-volume * market-price)
    if transaction-profit < 0 [
      set label "Loss"
    ]
  ]

  ;; === Calculate Inventory ===
  let committed-inventory sum [transaction-volume] of my-out-links
  set unsold-inventory max list 0 (inventory - committed-inventory)
  print (word "Contractor " who ": Inventory after commitments: " unsold-inventory)

  ;; === Apply Losses ===
  let transport-loss-amount sum [transaction-volume * (transport-loss / 100)] of my-in-links
  set inventory max list 0 (inventory - transport-loss-amount)
  let dynamic-storage-loss-rate ifelse-value storage-available? [0.05] [0.1]
  let storage-loss-amount unsold-inventory * dynamic-storage-loss-rate
  set inventory max list 0 (inventory - storage-loss-amount)
  print (word "Contractor " who ": Inventory after losses: " inventory)

  ;; === Financial Management ===
  set profit profit - (operating-cost * 0.2)
  if profit < -1000 [
    set operating-cost operating-cost * 0.7
    print (word "Contractor " who ": Operating cost reduced to: " operating-cost)
  ]

  ;; === Low Inventory Response ===
  ifelse inventory < 500 [
    print (word "Contractor " who ": Low inventory detected. Searching for suppliers.")
    let potential-suppliers farmers with [inventory > 0 ] ;and under-contract?]
    ifelse any? potential-suppliers [
    let best-farmer one-of potential-suppliers with-max [
  (quality / production-cost) * (1 / distance myself)
]
      print (word "Contractor " who ": Farmer " [who] of best-farmer " selected for transaction.")
      let purchase-volume min list 100 ([inventory] of best-farmer)
      let transaction-price market-price

      ;; Create a transaction to the farmer

     if (purchase-volume * transaction-price) <= profit [

     let markup 0.15  ;; 15% minimum profit margin
     let selling-price market-price * (1 + markup)
  create-transaction-to best-farmer [
    set transaction-volume purchase-volume
    set transaction-value purchase-volume * selling-price

    set duration 1
  ]

]
      ;; Update farmer's inventory and profit
      ask best-farmer [
        set inventory inventory - purchase-volume
        set profit profit + (purchase-volume * transaction-price)
      ]

      ;; Update contractor's inventory and profit
      set inventory inventory + purchase-volume
      set profit profit - (purchase-volume * transaction-price)
      print (word "Contractor " who ": Inventory updated to: " inventory)
      print (word "Contractor " who ": Profit updated to: " profit)
    ] [
      print (word "Contractor " who ": No eligible farmers available.")
    ]
  ] [
    print (word "Contractor " who ": Inventory is sufficient. No action needed.")
  ]
end
to wholesaler-decisions

  let committed-inventory sum [transaction-volume] of my-out-links
  let unsoldinventory inventory - committed-inventory
  if unsoldinventory < 0 [ set unsoldinventory 0 ]

  ; Time-dependent storage loss (using ticks as proxy for storage time)
  let loss-multiplier ifelse-value storage-available? [1] [1.5]  ; more loss if no storage...This amplifies loss when no storage infrastructure is present, simulating spoilage.
  let loss-percent storage-loss * loss-multiplier * (1 + (ticks / 100))

  let loss-amount unsoldinventory * (loss-percent / 100)
  set inventory inventory - loss-amount
   if not storage-available? and inventory > 100 [
  set inventory 100  ; can't store beyond a threshold
]
  set profit profit - operating-cost

  if profit < -1000 [
    set operating-cost operating-cost * 0.9
  ]

end

to retailer-decisions
  ;; Spoilage and discard logic
  let spoilage-rate (1 - (quality / 100)) * 0.1  ;; Spoilage rate is proportional to quality
  let spoilage-loss inventory * spoilage-rate    ;; Calculate spoilage loss
  set inventory inventory - spoilage-loss        ;; Reduce inventory by spoilage loss

  ;; Sales logic
  let markup 0.2                                  ;; Assume a fixed 20% markup
  let selling-price market-price * (1 + markup)   ;; Selling price based on markup
  let sales min list inventory (market-demand / count retailers)  ;; Distribute demand among retailers

  ;; Calculate profit from sales
  set profit profit + (sales * selling-price)     ;; Revenue from selling at selling price
  set inventory inventory - sales                 ;; Reduce inventory after sales

  ;; Financial management
  set profit profit - operating-cost              ;; Deduct operating costs from profit

  ;; Reordering logic
  if inventory < (market-demand / count retailers)* 0.75 [              ;; Request more inventory if stock is below half of demand
    let suitable-wholesalers wholesalers with [inventory > 0]
    if any? suitable-wholesalers [
      ;; Choose the wholesaler with the best quality inventory
      let chosen-wholesaler max-one-of suitable-wholesalers [quality]
      let purchase-volume min list ([inventory] of chosen-wholesaler) (market-demand / 3)
      let purchase-cost purchase-volume * market-price
      if (profit - purchase-cost) > 0 and inventory + purchase-volume <= max inventory [
         ;; Ensure profitability after the purchase
        create-transaction-from chosen-wholesaler [
          set transaction-volume purchase-volume
          set transaction-value purchase-cost
          set duration random 3 + 1
        ]
        set inventory inventory + purchase-volume  ;; Add purchased inventory
        set profit profit - purchase-cost          ;; Deduct purchase cost from profit
      ]
    ]
  ]
end
; ======================
; MARKET DYNAMICS
; ======================
to update-market-conditions
  ;; Ensure this procedure runs in the observer context

  ;; === Seasonal Multiplier ===
  let month (ticks mod 12)  ;; Works because `ticks` is accessible in the observer context

  set current-season-multiplier (ifelse-value (month >= 3 and month <= 8)
    [1.0 + (0.5 * (1 - abs (month - 6) / 6))]  ;; Bell curve peaking in June
    [0.7]  ;; Off-season discount
  )

  ;; === Quality Adjustment ===
  let farmers-with-inventory farmers with [inventory > 0]
  set current-quality-bonus ifelse-value (any? farmers-with-inventory) [
    1 + ((mean [quality] of farmers-with-inventory) - 60) / 150
  ][
    1.0  ;; Default when no inventory
  ]

  ;; === Supply-Demand Adjustment ===
  let total-supply sum [inventory] of retailers
  let supply-ratio ifelse-value (total-supply > 0) [
    (market-demand / total-supply) ^ 0.6
  ][
    4.0  ;; Shortage multiplier
  ]

  if not storage-available? [
    set current-season-multiplier current-season-multiplier * 0.9  ;; Price depression due to spoilage
  ]

  ;; === Final Market Price Calculation ===
  set market-price base-price * current-season-multiplier * current-quality-bonus * supply-ratio
  set market-price max list 25 (min list 100 market-price) ; price range 25-1


  ;; === Profit-Based Adjustment ===
  ;; Calculate contractor-profit (sum of all profits of contractors)
  let contractor-profit sum [profit] of contractors

  ;; Calculate total retailer profit (sum of all profits of retailers)
  let retailer-profit sum [profit] of retailers

  ;; Adjust market price based on contractor and retailer profits
  ifelse contractor-profit > 0 and retailer-profit > 0 [
    ;; If both profits are positive, adjust based on the ratio
    set market-price market-price * (1 + (contractor-profit / retailer-profit))
  ][
    ;; If contractor-profit is zero or negative, apply a small increase (e.g., 5%)
    set market-price market-price * 1.05
  ]

  ;; === Export Price Calculation ===
  set export-price market-price * 1.25
end

; ======================
; FOOD LOSS
; ======================

to calculate-food-loss

  ;; === Reset Loss Counters ===
  ;; Prevent cumulative overcounting by resetting counters each tick
  set total-preharvest-loss 0
  set total-postharvest-loss 0

  ;; === Compute Pre-Harvest Loss ===
  set pre-harvest-loss sum [
    ifelse-value climate-shock-active? [
      farm-size * 0.3  ;; 30% loss if climate shock is active
    ][
      ifelse-value pest-outbreak-active? [
        farm-size * 0.2  ;; 20% loss if pest outbreak is active
      ][
        0  ;; No pre-harvest loss otherwise
      ]
    ]
  ] of farmers with [under-contract?]  ;; Only consider farmers with active contracts

  ;; === Compute Post-Harvest Loss ===
  let contractor-transport-loss sum [
    inventory * (transport-loss / 100)
  ] of contractors  ;; Transport loss for contractors

  let wholesaler-storage-loss sum [
    inventory * (storage-loss / 100) * (ifelse-value storage-available? [1] [1.5])
  ] of wholesalers  ;; Storage loss for wholesalers with multiplier for storage availability

  ;; Calculate total post-harvest loss
  set post-harvest-loss contractor-transport-loss + wholesaler-storage-loss

  ;; === Update Global Totals for Display/Logging ===
  ;; Ensure no negative values for food loss
  set total-preharvest-loss max list 0 pre-harvest-loss
  set total-postharvest-loss max list 0 post-harvest-loss
  set total-food-loss total-preharvest-loss + total-postharvest-loss

  ;; Optional: Add visual or logging feedback
  show (word "Pre-Harvest Loss: " total-preharvest-loss)
  show (word "Post-Harvest Loss: " total-postharvest-loss)
  show (word "Total Food Loss: " total-food-loss)

end


; ======================
; VISUALIZATION
; ======================

to update-display
  ;; Season indicator (background color)
  let month (ticks mod 12)
  ifelse (month >= 3 and month <= 8) [
    ask patches [ set pcolor scale-color green month 3 8 ]  ; Green during season
  ][
    ask patches [ set pcolor gray ]  ; Gray off-season
  ]
  ask farmers [
    set size 0.3 + (farm-size / 150)
    set color scale-color yellow quality 40 90  ; Yellow = mango color
    set label ifelse-value ((ticks mod 12) >= 3 and (ticks mod 12) <= 8)
      [ "🍏" ]  ; Mango emoji during season
      [ "" ]
  ]

  ask turtles with [breed != farmers] [
    set color scale-color blue profit -1000 10000
  ]


  ask transactions [
    set thickness 0.1 + (transaction-volume / 200)
    set color scale-color red duration 1 6
  ]


  ;;;spoilage indication;;;
  ask contractors with [inventory > 0] [
    set shape "truck"
    set color scale-color red (inventory * (transport-loss / 100)) 0 50
  ]

  ask wholesalers with [inventory > 0] [
    set color scale-color orange (inventory * (storage-loss / 100)) 0 50
  ]
set-current-plot "Profit by Agent Type"
;;; Plotting profits bt breed;;;;;
set-current-plot-pen "Farmers"
plot mean [profit] of farmers

set-current-plot-pen "Contractors"
plot mean [profit] of contractors

set-current-plot-pen "Commission Agents"
plot mean [profit] of commission-agents

set-current-plot-pen "Wholesalers"
plot mean [profit] of wholesalers

set-current-plot-pen "Retailers"
plot mean [profit] of retailers
 ;;;;;
  set-current-plot "Quality vs Profit of farmers"
set-current-plot-pen "default"
ask farmers [
  plotxy quality profit
]
set-current-plot "Shocks Over Time"
set-current-plot-pen "Climate Shock"
plot (ifelse-value climate-shock-active? [1] [0])
set-current-plot-pen "Pest Shock"
plot (ifelse-value pest-outbreak-active? [1] [0])

set-current-plot "Shocks Over Time"
ifelse climate-shock-active? [ plot 1 ] [ plot 0 ]
plot (ifelse-value pest-outbreak-active? [1] [0])

end

; ======================
; UTILITY
; ======================

to check-environmental-risks
  set climate-shock-active? (random-float 1.0 < 0.1)
  set pest-outbreak-active? (random-float 1.0 < 0.15)
end

to maintain-contracts
  ; Just a placeholder for now
end
to consider-new-contracts
  if inventory > 0 [

        let deal-volume min list (inventory * 0.3) (capital-available / market-price) ;; Ensure deal-volume is feasible
    let deal-price market-price
    let deal-value deal-volume * deal-price

    show (word "Inventory: " inventory)
    show (word "Deal Volume: " deal-volume)
    show (word "Deal Value: " deal-value)

    let candidate-contractors contractors with [
      capital-available >= deal-value and self != myself ;; Exclude self
    ]

    show (word "Eligible Contractors: " count candidate-contractors)

    if any? candidate-contractors [
      let chosen-contractor one-of candidate-contractors

      create-transaction-to chosen-contractor [
        set transaction-volume deal-volume
        set transaction-value deal-value
        set duration random 3 + 2
        set color yellow
      ]

      set inventory inventory - deal-volume ;; Reduce inventory

      ask chosen-contractor [
        set capital-available capital-available - deal-value ;; Deduct capital
      ]

      show (word "Transaction created with: " who)
    ]

    if not any? candidate-contractors [
      show "⚠ No contractors with enough capital!"
    ]
  ]
end

to update-transactions
  let total-transaction-profit 0
  let transaction-count 0
  let invalid-transaction-count 0 ;; Track failed transactions

  ask transactions [
    set duration duration - 1
    if duration <= 0 [
      let seller end1
      let buyer end2
      let volume transaction-volume
      let value transaction-value

      ;; Validate transaction details
      if is-number? volume and is-number? value and volume > 0 [
        ifelse [inventory] of seller >= volume [
          ;; Process valid transactions
          ask seller [ set inventory inventory - volume ]
          ask buyer [ set inventory inventory + volume ]

          if ([capital-available] of buyer >= (value * 1.1)) [ask buyer [
            let transaction-cost value * 0.1 ;; Example: 10% transaction cost
            set profit profit - (value + transaction-cost)
            set total-transaction-profit total-transaction-profit + value
          ]
  ]

          ask seller [
            set profit profit + value
          ]
          set transaction-count transaction-count + 1
        ] [
          ;; Handle insufficient inventory
          set invalid-transaction-count invalid-transaction-count + 1
          show (word "⚠ Transaction failed: Seller inventory insufficient.")
        ]
      ]
      die ;; Remove completed transaction
    ]
  ]

  ifelse transaction-count > 0 [
    show (word "Average Transaction Profit: " (total-transaction-profit / transaction-count))
  ] [
    show "⚠ No transactions completed."
  ]

  show (word "Invalid Transactions: " invalid-transaction-count)
end

 to updateplots
  ;; ===== 1. QUALITY PLOTS =====
  set-current-plot "Quality Distribution"
  set-current-plot-pen "quality-histogram"
  set-plot-pen-interval 5
  let qualified-farmers farmers with [quality > 0]
  if any? qualified-farmers [
    histogram [quality] of qualified-farmers
  ]

  set-current-plot "Mean Quality Over Time"
  set-current-plot-pen "Mean Quality"
  if any? farmers with [quality > 0] [
    plot mean [quality] of farmers with [quality > 0]
  ]

  ;; ===== 2. SHOCK INDICATORS =====
  set-current-plot "Shocks Over Time"

set-current-plot-pen "Climate Shock"
plot (ifelse-value climate-shock-active? [1] [0])

set-current-plot-pen "Pest Shock"
plot (ifelse-value pest-outbreak-active? [1] [0])

  ;; ===== 3. FARMER ECONOMICS =====
  set-current-plot "Farmer Profit Comparison"
  let profitable-large farmers with [label = "L" and is-number? profit]
  let profitable-small farmers with [label = "S" and is-number? profit]

  set-current-plot-pen "Large Farmers"
  if any? profitable-large [ plot mean [profit] of profitable-large ]

  set-current-plot-pen "Small Farmers"
  if any? profitable-small [ plot mean [profit] of profitable-small ]

  set-current-plot "Small Farmer Struggle"
  set-current-plot-pen "Loss Incidents"
  plot count farmers with [label = "S" and profit < 0]

  set-current-plot "Profit Inequality"
  set-current-plot-pen "Farmer Profit Std Dev"
  let farmers-with-profit farmers with [is-number? profit]
  if count farmers-with-profit > 1 [
    plot standard-deviation [profit] of farmers-with-profit
  ]

  ;; ===== 4. FOOD LOSS TRACKING =====
  set-current-plot "Pre-Harvest Loss Over Time"
  set-current-plot-pen "Pre-harvest Loss"
  plot total-preharvest-loss

  set-current-plot "Post-harvest Loss Over Time"
  set-current-plot-pen "Post-harvest Loss"
  plot total-postharvest-loss

  ;; ===== 5. PRICE COMPONENTS =====
  set-current-plot "Price Components"
  set-current-plot-pen "Season Multiplier"
  plot current-season-multiplier

  set-current-plot-pen "Quality Bonus"
  plot current-quality-bonus

  set-current-plot-pen "Market Price"
  plot market-price

  ;; ===== 6. AGENT-TYPE PROFITS (FIXED) =====
  set-current-plot "Profit by Agent Type"

  ;; Farmers
  set-current-plot-pen "Farmers"
  let farmer-agents farmers with [is-number? profit]
  if any? farmer-agents [ plot mean [profit] of farmer-agents ]

  ;; Contractors
  set-current-plot-pen "Contractors"
  let contractor-agents contractors with [is-number? profit]
  if any? contractor-agents [ plot mean [profit] of contractor-agents ]

  ;; Commission Agents
  set-current-plot-pen "Commission Agents"
  let commissionagents commission-agents with [is-number? profit]
  if any? commission-agents [ plot mean [profit] of commission-agents ]

  ;; Wholesalers
  set-current-plot-pen "Wholesalers"
  let wholesaler-agents wholesalers with [is-number? profit]
  if any? wholesaler-agents [ plot mean [profit] of wholesaler-agents ]

  ;; Retailers
  set-current-plot-pen "Retailers"
  let retailer-agents retailers with [is-number? profit]
  if any? retailer-agents [ plot mean [profit] of retailer-agents ]
end
to to-check
  show (word "Total Unsold Inventory: " unsold-inventory)
  show (word "Total Farmer Profit: " sum [profit] of farmers)
  show (word "Total Contractor Profit: " sum [profit] of contractors)
  show (word "Total Retailer Profit: " sum [profit] of retailers)
  show (word "Total Farmer Inventory: " sum [inventory] of farmers)
  show (word "Total Contractor Inventory: " sum [inventory] of contractors)
  show (word "Total Retailer Inventory: " sum [inventory] of retailers)
  show (word "Market Price: " market-price)
  show (word "Market Demand: " market-demand)
end
to end-season
  ;; Reset contracts and inventory
  ask farmers [
    set under-contract? false
    set current-contractor nobody
  ]
  ask contractors [
    set inventory 0
  ]
  ask commission-agents [
    set inventory 0
  ]
  ask wholesalers [
    set inventory 0
  ]
  ask retailers [
    set inventory 0
  ]

  ;; Reset food loss metrics
  set total-preharvest-loss 0
  set total-postharvest-loss 0
  set total-food-loss 0
end
@#$#@#$#@
GRAPHICS-WINDOW
186
10
623
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
9
15
73
48
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
86
16
149
49
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
630
165
886
315
Food Loss Over Time
ticks
Volume
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"pre-harvest-loss" 1.0 0 -16777216 true "" "plot pre-harvest-loss"
"post-harvest-loss" 1.0 0 -7500403 true "" "plot post-harvest-loss"
"total-food-loss" 1.0 0 -2674135 true "" "plot total-food-loss"

PLOT
630
12
881
162
Total Profit Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "plot total-profit"
PENS
"total-profit" 1.0 0 -16777216 true "" ""

PLOT
887
13
1133
161
Market-price
NIL
NIL
0.0
10.0
0.0
60.0
true
false
"" ""
PENS
"market-price" 1.0 0 -16777216 true "" "plot market-price"

PLOT
893
165
1136
315
Quality Distribution
NIL
NIL
1.0
100.0
0.0
20.0
true
false
"" ""
PENS
"quality-histogram" 1.0 1 -7500403 true "" ""

PLOT
629
318
829
468
Mean Quality Over Time
ticks
Mean Quality
0.0
10.0
0.0
10.0
true
true
"" "\n\n\n"
PENS
"Mean Quality" 1.0 0 -16777216 true "" ""
"Climate Shock" 1.0 0 -14070903 true "" ""
"Pest Shock" 1.0 0 -2674135 true "" ""

MONITOR
1
64
182
109
Large farmers mean profit
mean [profit] of farmers with [label = \"L\"]
17
1
11

MONITOR
0
112
181
157
Small farmer Mean profit
mean [profit] of farmers with [label = \"S\"]
17
1
11

MONITOR
1
161
154
206
Large farmers mean quality
mean [quality] of farmers with [label = \"L\"]
17
1
11

MONITOR
0
210
155
255
Small farmers mean quality
mean [quality] of farmers with [label = \"S\"]
17
1
11

PLOT
860
325
1090
475
Farmer Profit Comparison
Ticks
Profits
0.0
1500.0
0.0
15000.0
true
true
"" "\n"
PENS
"Large Farmers" 1.0 0 -16777216 true "plot mean [profit] of farmers with [label = \"L\"]\n\n" ""
"Small Farmers" 1.0 0 -2674135 true "" ""

PLOT
1093
325
1293
475
Profit by Agent Type
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Farmers" 1.0 0 -16777216 true "" ""
"Contractors" 1.0 0 -7858858 true "" ""
"Commission Agents" 1.0 0 -2674135 true "" ""
"Wholesalers" 1.0 0 -955883 true "" ""
"Retailers" 1.0 0 -13345367 true "" ""

PLOT
1139
164
1339
314
Quality vs Profit of farmers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
1137
11
1337
161
Shocks Over Time
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"Climate Shock" 1.0 0 -16777216 true "" ""
"Pest Shock" 1.0 0 -817084 true "" ""

PLOT
1295
326
1495
476
Small Farmer Struggle
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Loss Incidents" 1.0 0 -16777216 true "" ""

PLOT
1343
10
1543
160
Profit Inequality
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Farmer Profit Std Dev" 1.0 0 -16777216 true "" ""

SLIDER
0
260
172
293
Preharvestloss
Preharvestloss
0
100
10.0
10
1
%
HORIZONTAL

SLIDER
0
293
172
326
postharvestloss
postharvestloss
0
100
10.0
1
1
%
HORIZONTAL

PLOT
1343
166
1543
316
Pre-Harvest Loss Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Pre-harvest Loss" 1.0 0 -955883 true "" ""

PLOT
1547
166
1747
316
Post-harvest Loss Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Post-harvest Loss" 1.0 0 -16777216 true "" ""

MONITOR
0
342
154
387
NIL
mean [quality] of farmers
17
1
11

PLOT
1558
10
1758
160
Price Components
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Season Multiplier" 1.0 0 -16777216 true "" ""
"Quality Bonus" 1.0 0 -7500403 true "" ""
"Market Price" 1.0 0 -2674135 true "" ""

SLIDER
5
404
177
437
BYL
BYL
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
15
444
187
477
BYS
BYS
0
1
0.05
.01
1
NIL
HORIZONTAL

MONITOR
206
472
302
517
Farmer 0 Profit
[profit] of farmer 0
17
1
11

MONITOR
309
473
429
518
contractor 0 capital
[capital-available] of contractor 0
17
1
11

MONITOR
435
474
521
519
Avg deal size
mean [transaction-volume] of transactions
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
