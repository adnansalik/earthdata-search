import React from 'react'
import Enzyme, { shallow } from 'enzyme'
import Adapter from 'enzyme-adapter-react-16'

import ProjectCollectionsItem from '../ProjectCollectionsItem'


Enzyme.configure({ adapter: new Adapter() })

function setup() {
  const props = {
    collectionId: 'collectionId',
    collection: {
      excludedGranuleIds: [
        'G10000001-EDSC'
      ],
      granules: {
        hits: 4,
        totalSize: { size: '4.0', unit: 'MB' }
      },
      metadata: {
        dataset_id: 'Collection Title',
        granule_count: 4
      }
    },
    color: 'color',
    index: 0,
    isPanelActive: false,
    onRemoveCollectionFromProject: jest.fn(),
    onToggleCollectionVisibility: jest.fn(),
    onSetActivePanel: jest.fn(),
    projectCollection: {
      accessMethods: {}
    },
    collectionSearch: {}
  }

  const enzymeWrapper = shallow(<ProjectCollectionsItem {...props} />)

  return {
    enzymeWrapper,
    props
  }
}

describe('ProjectCollectionItem component', () => {
  test('renders itself correctly', () => {
    const { enzymeWrapper } = setup()

    expect(enzymeWrapper.find('h3').text()).toEqual('Collection Title')
    expect(enzymeWrapper.find('.project-collections-item__stats-item--granule-count').text()).toEqual('3 Granules')
    expect(enzymeWrapper.find('.project-collections-item__stats-item--total-size').text()).toEqual('Est. Size 4.0 MB')
  })

  test('Remove from project button calls onRemoveCollectionFromProject', () => {
    const { enzymeWrapper, props } = setup()

    const button = enzymeWrapper.find('.project-collections-item__more-actions-remove')

    button.simulate('click')
    expect(props.onRemoveCollectionFromProject).toHaveBeenCalledTimes(1)
    expect(props.onRemoveCollectionFromProject).toHaveBeenCalledWith('collectionId')
  })

  test('Toggle visibility button calls onToggleCollectionVisibility', () => {
    const { enzymeWrapper, props } = setup()

    const button = enzymeWrapper.find('.project-collections-item__more-actions-vis')

    button.simulate('click')
    expect(props.onToggleCollectionVisibility).toHaveBeenCalledTimes(1)
    expect(props.onToggleCollectionVisibility).toHaveBeenCalledWith('collectionId')
  })

  describe('validity icon', () => {
    test('shows invalid by default', () => {
      const { enzymeWrapper } = setup()
      expect(enzymeWrapper.find('.project-collections-item__status--invalid').length).toEqual(1)
    })

    test('removes icon with a valid project collection', () => {
      const { enzymeWrapper } = setup()
      enzymeWrapper.setProps({
        projectCollection: {
          accessMethods: {
            download: {
              isValid: true,
              type: 'download'
            }
          },
          selectedAccessMethod: 'download'
        }
      })
      expect(enzymeWrapper.find('.project-collections-item__status--invalid').length).toEqual(0)
    })
  })
})