#Requires -Version 7.2

$AADCANamedLocationDisplayNamePrefix = $null

$AADCANamedLocations = @(
    #:-------------------------------------------------------------------------
    # Tier 0 Named Locations
    #
    @(
        #:--- Countries
        @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier0-Admin-Allowed-Country-IP-Locations') | Join-String -Separator $DisplayNameElementSeparator
            '@odata.type' = '#microsoft.graph.countryNamedLocation'

            # Country codes, based on ISO 3166-1
            CountriesAndRegions = @(
                #:--- European Union (EU) Member States
                'AT'    # Austria
                'BE'    # Belgium
                'BG'    # Bulgaria
                'HR'    # Croatia
                'CY'    # Cyprus
                'CZ'    # Czechia
                'DK'    # Denmark
                'EE'    # Estonia
                'FI'    # Finland
                'FR'    # France
                'DE'    # Germany
                'GR'    # Greece
                'HU'    # Hungary
                'IE'    # Ireland
                'IT'    # Italy
                'LV'    # Latvia
                'LT'    # Lithuania
                'LU'    # Luxembourg
                'MT'    # Malta
                'NL'    # Netherlands
                'PL'    # Poland
                'PT'    # Portugal
                'RO'    # Romania
                'SK'    # Slovakia
                'SI'    # Slovenia
                'ES'    # Spain
                'SE'    # Sweden

                #:--- Member States of the European Free Trade Association (EFTA)
                # 'IS'    # Iceland
                # 'LI'    # Liechtenstein
                # 'NO'    # Norway
                # 'CH'    # Switzerland

                #:--- EU candidate countries (official status)
                # 'AL'    # Albania
                # 'ME'    # Montenegro
                # 'MK'    # North Macedonia
                # 'RS'    # Serbia
                # 'TR'    # Türkiye

                #:--- Other European countries
                # 'AD'    # Andorra
                # 'BY'    # Belarus
                # 'BA'    # Bosnia and Herzegovina
                # 'MD'    # Moldova, Republic of
                # 'MC'    # Monaco
                # 'RU'    # Russian Federation
                # 'SM'    # San Marino
                # 'UA'    # Ukraine
                # 'GB'    # United Kingdom

                #:--- North American countries
                # 'CA'    # Canada
                # 'US'    # United States of America

                #:--- South American countries
                # 'BR'    # Brazil
                # 'CO'    # Colombia

                #:--- African countries
                # 'EG'    # Egypt
                # 'ET'    # Ethiopia
                # 'NG'    # Nigeria

                #:--- Asian countries
                # 'CN'    # China
                # 'IN'    # India
                # 'ID'    # Indonesia

                #:--- Oceanian countries
                # 'AU'    # Australia
                # 'NZ'    # New Zealand

                #:--- Antarctica
                # 'AQ'    # Antarctica
            )
            IncludeUnknownCountriesAndRegions = $false
        }

        #:--- Corporate IPs
        # @{
        #     # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
        #     displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier0-Admin-Allowed-Corporate-IPs') | Join-String -Separator $DisplayNameElementSeparator
        #     '@odata.type' = '#microsoft.graph.ipNamedLocation'

        #     isTrusted = $false
        #     ipRanges = @(
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv4CidrRange"
        #             CidrAddress = "192.0.2.0/24"
        #         }
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv6CidrRange"
        #             CidrAddress = "2001:db8::/64"
        #         }
        #     )
        # }
    ),

    #:-------------------------------------------------------------------------
    # Tier 1 Named Locations
    #
    @(
        #:--- Countries
        @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier1-Admin-Allowed-Country-IP-Locations') | Join-String -Separator $DisplayNameElementSeparator
            '@odata.type' = '#microsoft.graph.countryNamedLocation'

            # Country codes, based on ISO 3166-1
            CountriesAndRegions = @(
                #:--- European Union (EU) Member States
                'AT'    # Austria
                'BE'    # Belgium
                'BG'    # Bulgaria
                'HR'    # Croatia
                'CY'    # Cyprus
                'CZ'    # Czechia
                'DK'    # Denmark
                'EE'    # Estonia
                'FI'    # Finland
                'FR'    # France
                'DE'    # Germany
                'GR'    # Greece
                'HU'    # Hungary
                'IE'    # Ireland
                'IT'    # Italy
                'LV'    # Latvia
                'LT'    # Lithuania
                'LU'    # Luxembourg
                'MT'    # Malta
                'NL'    # Netherlands
                'PL'    # Poland
                'PT'    # Portugal
                'RO'    # Romania
                'SK'    # Slovakia
                'SI'    # Slovenia
                'ES'    # Spain
                'SE'    # Sweden

                #:--- Member States of the European Free Trade Association (EFTA)
                'IS'    # Iceland
                'LI'    # Liechtenstein
                'NO'    # Norway
                'CH'    # Switzerland

                #:--- EU candidate countries (official status)
                # 'AL'    # Albania
                # 'ME'    # Montenegro
                # 'MK'    # North Macedonia
                # 'RS'    # Serbia
                # 'TR'    # Türkiye

                #:--- Other European countries
                # 'AD'    # Andorra
                # 'BY'    # Belarus
                # 'BA'    # Bosnia and Herzegovina
                # 'MD'    # Moldova, Republic of
                # 'MC'    # Monaco
                # 'RU'    # Russian Federation
                # 'SM'    # San Marino
                # 'UA'    # Ukraine
                'GB'    # United Kingdom

                #:--- North American countries
                'CA'    # Canada
                'US'    # United States of America

                #:--- South American countries
                # 'BR'    # Brazil
                # 'CO'    # Colombia

                #:--- African countries
                # 'EG'    # Egypt
                # 'ET'    # Ethiopia
                # 'NG'    # Nigeria

                #:--- Asian countries
                # 'CN'    # China
                # 'IN'    # India
                # 'ID'    # Indonesia

                #:--- Oceanian countries
                # 'AU'    # Australia
                # 'NZ'    # New Zealand

                #:--- Antarctica
                # 'AQ'    # Antarctica
            )
            IncludeUnknownCountriesAndRegions = $false
        }

        #:--- Corporate IPs
        # @{
        #     # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
        #     displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier1-Admin-Allowed-Corporate-IPs') | Join-String -Separator $DisplayNameElementSeparator
        #     '@odata.type' = '#microsoft.graph.ipNamedLocation'

        #     isTrusted = $false
        #     ipRanges = @(
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv4CidrRange"
        #             CidrAddress = "192.0.2.0/24"
        #         }
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv6CidrRange"
        #             CidrAddress = "2001:db8::/64"
        #         }
        #     )
        # }
    ),

    #:-------------------------------------------------------------------------
    # Tier 2 Named Locations
    #
    @(
        #:--- Countries
        @{
            # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
            displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier2-Admin-Allowed-Country-IP-Locations') | Join-String -Separator $DisplayNameElementSeparator
            '@odata.type' = '#microsoft.graph.countryNamedLocation'

            # Country codes, based on ISO 3166-1
            CountriesAndRegions = @(
                #:--- European Union (EU) Member States
                'AT'    # Austria
                'BE'    # Belgium
                'BG'    # Bulgaria
                'HR'    # Croatia
                'CY'    # Cyprus
                'CZ'    # Czechia
                'DK'    # Denmark
                'EE'    # Estonia
                'FI'    # Finland
                'FR'    # France
                'DE'    # Germany
                'GR'    # Greece
                'HU'    # Hungary
                'IE'    # Ireland
                'IT'    # Italy
                'LV'    # Latvia
                'LT'    # Lithuania
                'LU'    # Luxembourg
                'MT'    # Malta
                'NL'    # Netherlands
                'PL'    # Poland
                'PT'    # Portugal
                'RO'    # Romania
                'SK'    # Slovakia
                'SI'    # Slovenia
                'ES'    # Spain
                'SE'    # Sweden

                #:--- Member States of the European Free Trade Association (EFTA)
                'IS'    # Iceland
                'LI'    # Liechtenstein
                'NO'    # Norway
                'CH'    # Switzerland

                #:--- EU candidate countries (official status)
                # 'AL'    # Albania
                # 'ME'    # Montenegro
                # 'MK'    # North Macedonia
                # 'RS'    # Serbia
                # 'TR'    # Türkiye

                #:--- Other European countries
                # 'AD'    # Andorra
                # 'BY'    # Belarus
                # 'BA'    # Bosnia and Herzegovina
                # 'MD'    # Moldova, Republic of
                # 'MC'    # Monaco
                # 'RU'    # Russian Federation
                # 'SM'    # San Marino
                # 'UA'    # Ukraine
                'GB'    # United Kingdom

                #:--- North American countries
                'CA'    # Canada
                'US'    # United States of America

                #:--- South American countries
                # 'BR'    # Brazil
                # 'CO'    # Colombia

                #:--- African countries
                # 'EG'    # Egypt
                # 'ET'    # Ethiopia
                # 'NG'    # Nigeria

                #:--- Asian countries
                # 'CN'    # China
                # 'IN'    # India
                # 'ID'    # Indonesia

                #:--- Oceanian countries
                # 'AU'    # Australia
                # 'NZ'    # New Zealand

                #:--- Antarctica
                # 'AQ'    # Antarctica
            )
            IncludeUnknownCountriesAndRegions = $false
        }

        #:--- Corporate IPs
        # @{
        #     # id = ''   # This is tenant specific and may be added after initial creation to use GUID instead of name
        #     displayName = @($AADCANamedLocationDisplayNamePrefix, 'Tier2-Admin-Allowed-Corporate-IPs') | Join-String -Separator $DisplayNameElementSeparator
        #     '@odata.type' = '#microsoft.graph.ipNamedLocation'

        #     isTrusted = $false
        #     ipRanges = @(
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv4CidrRange"
        #             CidrAddress = "192.0.2.0/24"
        #         }
        #         @{
        #             "@odata.type" = "#microsoft.graph.iPv6CidrRange"
        #             CidrAddress = "2001:db8::/64"
        #         }
        #     )
        # }
    )
)
