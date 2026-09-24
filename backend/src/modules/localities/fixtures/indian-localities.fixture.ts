export interface LocalityItem {
  id: string;
  countryCode: string;
  state: string;
  district: string;
  city: string;
  locality: string;
  postalCode?: string;
  popularNeighborhoods?: string[];
}

/**
 * Curated development fixture dataset for Indian localities.
 * Provides realistic autocomplete and selection for the Phase 2 onboarding flow.
 */
export const INDIAN_LOCALITIES_FIXTURE: LocalityItem[] = [
  // Bengaluru, Karnataka
  {
    id: 'loc-blr-01',
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Indiranagar',
    postalCode: '560038',
    popularNeighborhoods: ['100 Feet Road', 'Defence Colony', 'HAL 2nd Stage'],
  },
  {
    id: 'loc-blr-02',
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Koramangala',
    postalCode: '560034',
    popularNeighborhoods: ['4th Block', '5th Block', '6th Block'],
  },
  {
    id: 'loc-blr-03',
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'HSR Layout',
    postalCode: '560102',
    popularNeighborhoods: ['Sector 1', 'Sector 2', 'Sector 3', 'Sector 7'],
  },
  {
    id: 'loc-blr-04',
    countryCode: 'IN',
    state: 'Karnataka',
    district: 'Bengaluru Urban',
    city: 'Bengaluru',
    locality: 'Whitefield',
    postalCode: '560066',
    popularNeighborhoods: ['ITPL', 'Hope Farm', 'ECC Road'],
  },

  // Delhi NCR
  {
    id: 'loc-del-01',
    countryCode: 'IN',
    state: 'Delhi',
    district: 'New Delhi',
    city: 'New Delhi',
    locality: 'Connaught Place',
    postalCode: '110001',
    popularNeighborhoods: ['Inner Circle', 'Barakhamba Road', 'Janpath'],
  },
  {
    id: 'loc-del-02',
    countryCode: 'IN',
    state: 'Delhi',
    district: 'South Delhi',
    city: 'New Delhi',
    locality: 'Hauz Khas',
    postalCode: '110016',
    popularNeighborhoods: ['Hauz Khas Village', 'Mayfair Gardens', 'Kaushalya Park'],
  },
  {
    id: 'loc-del-03',
    countryCode: 'IN',
    state: 'Delhi',
    district: 'South Delhi',
    city: 'New Delhi',
    locality: 'Saket',
    postalCode: '110017',
    popularNeighborhoods: ['Press Enclave', 'J-Block', 'City Centre'],
  },
  {
    id: 'loc-del-04',
    countryCode: 'IN',
    state: 'Haryana',
    district: 'Gurugram',
    city: 'Gurugram',
    locality: 'DLF Phase 5',
    postalCode: '122002',
    popularNeighborhoods: ['Golf Course Road', 'The Aralias', 'Horizon Center'],
  },
  {
    id: 'loc-del-05',
    countryCode: 'IN',
    state: 'Uttar Pradesh',
    district: 'Gautam Buddha Nagar',
    city: 'Noida',
    locality: 'Sector 62',
    postalCode: '201309',
    popularNeighborhoods: ['Block B', 'Institutional Area'],
  },

  // Mumbai, Maharashtra
  {
    id: 'loc-mum-01',
    countryCode: 'IN',
    state: 'Maharashtra',
    district: 'Mumbai Suburban',
    city: 'Mumbai',
    locality: 'Bandra West',
    postalCode: '400050',
    popularNeighborhoods: ['Pali Hill', 'Carter Road', 'Hill Road', 'Bandstand'],
  },
  {
    id: 'loc-mum-02',
    countryCode: 'IN',
    state: 'Maharashtra',
    district: 'Mumbai Suburban',
    city: 'Mumbai',
    locality: 'Andheri West',
    postalCode: '400058',
    popularNeighborhoods: ['Lokhandwala Complex', 'Four Bungalows', 'Versova'],
  },
  {
    id: 'loc-mum-03',
    countryCode: 'IN',
    state: 'Maharashtra',
    district: 'Mumbai City',
    city: 'Mumbai',
    locality: 'Colaba',
    postalCode: '400005',
    popularNeighborhoods: ['Cuffe Parade', 'Apollo Bunder', 'Pastoria'],
  },

  // Pune, Maharashtra
  {
    id: 'loc-pun-01',
    countryCode: 'IN',
    state: 'Maharashtra',
    district: 'Pune',
    city: 'Pune',
    locality: 'Koregaon Park',
    postalCode: '411001',
    popularNeighborhoods: ['North Main Road', 'South Main Road', 'Lane 7'],
  },
  {
    id: 'loc-pun-02',
    countryCode: 'IN',
    state: 'Maharashtra',
    district: 'Pune',
    city: 'Pune',
    locality: 'Kothrud',
    postalCode: '411038',
    popularNeighborhoods: ['Dahanukar Colony', 'Ideal Colony', 'Mayur Colony'],
  },

  // Meerut, Uttar Pradesh
  {
    id: 'loc-mee-01',
    countryCode: 'IN',
    state: 'Uttar Pradesh',
    district: 'Meerut',
    city: 'Meerut',
    locality: 'Shastri Nagar',
    postalCode: '250004',
    popularNeighborhoods: ['Sector 1', 'Sector 2', 'Sector 3', 'Pocket B'],
  },
  {
    id: 'loc-mee-02',
    countryCode: 'IN',
    state: 'Uttar Pradesh',
    district: 'Meerut',
    city: 'Meerut',
    locality: 'Civil Lines',
    postalCode: '250001',
    popularNeighborhoods: ['Saket', 'Boundary Road', 'Circuit House Area'],
  },

  // Hyderabad, Telangana
  {
    id: 'loc-hyd-01',
    countryCode: 'IN',
    state: 'Telangana',
    district: 'Hyderabad',
    city: 'Hyderabad',
    locality: 'Banjara Hills',
    postalCode: '500034',
    popularNeighborhoods: ['Road No 1', 'Road No 12', 'Mithila Nagar'],
  },
  {
    id: 'loc-hyd-02',
    countryCode: 'IN',
    state: 'Telangana',
    district: 'Hyderabad',
    city: 'Hyderabad',
    locality: 'Jubilee Hills',
    postalCode: '500033',
    popularNeighborhoods: ['Road No 36', 'Film Nagar', 'Prashasan Nagar'],
  },

  // Jaipur, Rajasthan
  {
    id: 'loc-jai-01',
    countryCode: 'IN',
    state: 'Rajasthan',
    district: 'Jaipur',
    city: 'Jaipur',
    locality: 'Malviya Nagar',
    postalCode: '302017',
    popularNeighborhoods: ['Sector 1', 'Sector 3', 'Calgiri Marg'],
  },
  {
    id: 'loc-jai-02',
    countryCode: 'IN',
    state: 'Rajasthan',
    district: 'Jaipur',
    city: 'Jaipur',
    locality: 'Vaishali Nagar',
    postalCode: '302021',
    popularNeighborhoods: ['Amrapali Circle', 'Gandhi Path', 'Nursery Circle'],
  },
];
